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

@MainActor
@Observable
final class PremiumManager {
    private enum PremiumManagerError: Error {
        case missingCustomerInfo
    }

#if DEBUG
    private static let debugPremiumEnabledKey = "debugPremiumEnabled"
#endif

    static let shared = PremiumManager()

    private(set) var isPremium = false
    private(set) var isLoading = false
    private(set) var subscriptionExpirationDate: Date?
    private(set) var subscriptionWillRenew: Bool?
    private(set) var paywallPresentationToken = UUID()
#if DEBUG
    var isDebugPremiumEnabled = UserDefaults.standard.bool(forKey: debugPremiumEnabledKey) {
        didSet {
            UserDefaults.standard.set(isDebugPremiumEnabled, forKey: Self.debugPremiumEnabledKey)
            updatePremiumAccess(isEnabled: isDebugPremiumEnabled)
        }
    }
#endif
    private let entitlementId = "pro"

    private var pendingAction: (() -> Void)?
    private var customerInfoTask: Task<Void, Never>?

    private init() {
#if DEBUG
        updatePremiumAccess(isEnabled: isDebugPremiumEnabled)
#endif
        checkPremiumStatus()
        setupCustomerInfoStream()
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

        Task { [weak self] in
            guard let self else { return }

            defer {
                self.isLoading = false
            }

            do {
                let customerInfo = try await self.fetchCustomerInfo()
                self.apply(customerInfo: customerInfo)
#if DEBUG
                print("✅ Premium status: \(self.isPremium)")
#endif
            } catch {
                print("❌ Error checking premium status: \(error)")
            }
        }
    }

    private func setupCustomerInfoStream() {
        customerInfoTask = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard let self else { return }
                self.apply(customerInfo: customerInfo)
#if DEBUG
                print("📱 CustomerInfo updated. Premium: \(self.isPremium)")
#endif
            }
        }
    }


    // MARK: - Premium Actions

    func requirePremium(for feature: String = "", onPurchaseComplete: (() -> Void)? = nil) {
        if !isPremium {
            pendingAction = onPurchaseComplete
            paywallPresentationToken = UUID()
        }
    }

    // MARK: - Purchase Actions

    func restorePurchases() async {
#if DEBUG
        print("🔄 Syncing purchases...")
#endif
        do {
            let customerInfo = try await Purchases.shared.syncPurchases()
            apply(customerInfo: customerInfo)
#if DEBUG
            print("✅ Purchases synced. Premium: \(self.isPremium)")
#endif
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
        guard !isLoading else { return }

        isLoading = true

        defer {
            isLoading = false
        }

        do {
            let customerInfo = try await fetchCustomerInfo()
            apply(customerInfo: customerInfo)
#if DEBUG
            print("✅ Subscription status checked. Premium: \(self.isPremium)")
#endif
        } catch {
            print("❌ Error checking subscription status: \(error)")
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
        apply(customerInfo: customerInfo)
#if DEBUG
        print("✅ Premium status force updated: \(self.isPremium)")
#endif
    }

    private func fetchCustomerInfo() async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getCustomerInfo { customerInfo, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let customerInfo else {
                    continuation.resume(throwing: PremiumManagerError.missingCustomerInfo)
                    return
                }

                continuation.resume(returning: customerInfo)
            }
        }
    }

    private func apply(customerInfo: CustomerInfo) {
#if DEBUG
        updatePremiumAccess(isEnabled: isDebugPremiumEnabled)
#else
        updatePremiumAccess(isEnabled: !customerInfo.entitlements.active.isEmpty)
#endif
        updateEntitlementInfo(from: customerInfo)
    }

    private func updatePremiumAccess(isEnabled: Bool) {
        isPremium = isEnabled
#if DEBUG
        WidgetPremiumAccessStore.syncDebug(isPremium: isPremium)
#else
        WidgetPremiumAccessStore.sync(isPremium: isPremium)
#endif

        if isPremium, let action = pendingAction {
            pendingAction = nil
            action()
        }
    }

    private func updateEntitlementInfo(from customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements.active[entitlementId]
        subscriptionExpirationDate = entitlement?.expirationDate
        subscriptionWillRenew = entitlement?.willRenew
    }

}
