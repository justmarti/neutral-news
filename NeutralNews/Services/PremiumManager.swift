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
            NotificationCenter.default.post(name: .showPaywall, object: feature)
        }
    }

    // MARK: - Purchase Actions

    func restorePurchases() async {
#if DEBUG
        print("🔄 Restoring purchases...")
#endif
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await MainActor.run {
                self.isPremium = !customerInfo.entitlements.active.isEmpty
#if DEBUG
                print("✅ Purchases restored. Premium: \(self.isPremium)")
#endif

                // Execute pending action if user became premium
                if self.isPremium, let action = self.pendingAction {
                    self.pendingAction = nil
                    action()
                }
            }
        } catch {
            print("❌ Error restoring purchases: \(error)")
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

    // MARK: - Internal Methods

    func updatePremiumStatus(_ customerInfo: CustomerInfo) async {
        await MainActor.run {
            self.isPremium = !customerInfo.entitlements.active.isEmpty
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

}

// MARK: - Notification Extensions

extension Notification.Name {
    static let showPaywall = Notification.Name("ShowPaywall")
}
