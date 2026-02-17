//
//  PremiumManager.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 23/9/25.
//

import Foundation
import RevenueCat
import StoreKit
import Observation

@Observable
final class PremiumManager {
    static let shared = PremiumManager()

    private(set) var isPremium = false
    private(set) var isLoading = false
    private(set) var subscriptionExpirationDate: Date?
    private(set) var subscriptionWillRenew: Bool?
    private(set) var paywallPresentationToken = UUID()
    private let entitlementId = "pro"

    private var pendingAction: (() -> Void)?
    private var customerInfoTask: Task<Void, Never>?

    private init() {
        checkPremiumStatus()
        setupCustomerInfoStream()
    }

    deinit {
        customerInfoTask?.cancel()
    }

    // MARK: - Premium Features Access

    var canSaveNews: Bool {
        isPremium
    }

    var canViewAllDays: Bool {
        isPremium
    }

    func canViewDay(_ day: DayInfo) -> Bool {
        guard !isPremium else { return true }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dayDate = calendar.startOfDay(for: day.date)

        return dayDate >= yesterday
    }

    // MARK: - Premium Status Management

    private func checkPremiumStatus() {
        guard !isLoading else { return }

        isLoading = true

        Purchases.shared.getCustomerInfo { [weak self] info, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    print("❌ Error checking premium status: \(error)")
                    return
                }

                self?.isPremium = !(info?.entitlements.active.isEmpty ?? true)
                if let info {
                    self?.updateEntitlementInfo(from: info)
                }
#if DEBUG
                print("✅ Premium status: \(self?.isPremium ?? false)")
#endif
            }
        }
    }

    private func setupCustomerInfoStream() {
        customerInfoTask = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                await MainActor.run { [weak self] in
                    guard let self else { return }

                    self.isPremium = !customerInfo.entitlements.active.isEmpty
                    self.updateEntitlementInfo(from: customerInfo)
#if DEBUG
                    print("📱 CustomerInfo updated. Premium: \(self.isPremium)")
#endif

                    // Execute pending action if user became premium
                    if self.isPremium, let action = self.pendingAction {
                        self.pendingAction = nil
                        action()
                    }
                }
            }
        }
    }


    // MARK: - Premium Actions

    func requirePremium(for feature: String = "", onPurchaseComplete: (() -> Void)? = nil) {
        if !isPremium {
            pendingAction = onPurchaseComplete
            Task { @MainActor in
                self.paywallPresentationToken = UUID()
            }
        }
    }

    // MARK: - Purchase Actions

    func restorePurchases() async {
#if DEBUG
        print("🔄 Syncing purchases...")
#endif
        do {
            let customerInfo = try await Purchases.shared.syncPurchases()
            await MainActor.run {
                self.isPremium = !customerInfo.entitlements.active.isEmpty
#if DEBUG
                print("✅ Purchases synced. Premium: \(self.isPremium)")
#endif

                // Execute pending action if user became premium
                if self.isPremium, let action = self.pendingAction {
                    self.pendingAction = nil
                    action()
                }
            }
        } catch {
            print("❌ Error syncing purchases: \(error)")
        }
    }

    @MainActor
    func presentOfferCodeRedemption() async {
#if DEBUG
        print("🎟️ Presenting offer code redemption sheet")
#endif
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
    }

    // MARK: - Subscription Management

    func checkSubscriptionStatus() async {
        await MainActor.run {
            self.isLoading = true
        }

        await withCheckedContinuation { continuation in
            Purchases.shared.getCustomerInfo { customerInfo, error in
                Task {
                    await MainActor.run {
                        self.isLoading = false

                        if let error = error {
                            print("❌ Error checking subscription status: \(error)")
                        } else {
                            self.isPremium = !(customerInfo?.entitlements.active.isEmpty ?? true)
                            if let customerInfo {
                                self.updateEntitlementInfo(from: customerInfo)
                            }
#if DEBUG
                            print("✅ Subscription status checked. Premium: \(self.isPremium)")
#endif

                            // Execute pending action if user became premium
                            if self.isPremium, let action = self.pendingAction {
                                self.pendingAction = nil
                                action()
                            }
                        }

                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Refreshes premium state when app becomes active.
    ///
    /// Uses a lightweight status check first, and only attempts `syncPurchases()`
    /// when still non-premium to capture redemptions made outside the app
    /// (for example, App Store offer-code flows).
    func refreshSubscriptionStatusAfterActivation() async {
        await checkSubscriptionStatus()

        // If already premium, no sync is needed.
        guard !isPremium else { return }

        do {
            let customerInfo = try await Purchases.shared.syncPurchases()
            await updatePremiumStatus(customerInfo)
#if DEBUG
            print("✅ Foreground sync completed")
#endif
        } catch {
            print("⚠️ Foreground sync failed: \(error)")
        }
    }

    // MARK: - Internal Methods

    func updatePremiumStatus(_ customerInfo: CustomerInfo) async {
        await MainActor.run {
            self.isPremium = !customerInfo.entitlements.active.isEmpty
            self.updateEntitlementInfo(from: customerInfo)
#if DEBUG
            print("✅ Premium status force updated: \(self.isPremium)")
#endif

            // Execute pending action if user became premium
            if self.isPremium, let action = self.pendingAction {
                self.pendingAction = nil
                action()
            }
        }
    }

    private func updateEntitlementInfo(from customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements.active[entitlementId]
        subscriptionExpirationDate = entitlement?.expirationDate
        subscriptionWillRenew = entitlement?.willRenew
    }

}
