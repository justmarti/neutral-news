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
#if DEBUG
    private static let debugPremiumAccessModeKey = "debugPremiumAccessMode"
#endif

    static let shared = PremiumManager()

    private(set) var isPremium = false
    private(set) var isLoading = false
    private(set) var subscriptionExpirationDate: Date?
    private(set) var subscriptionWillRenew: Bool?
    private(set) var paywallPresentationToken = UUID()
#if DEBUG
    var debugPremiumAccessMode = DebugPremiumAccessMode(
        rawValue: UserDefaults.standard.string(forKey: debugPremiumAccessModeKey) ?? ""
    ) ?? .revenueCat {
        didSet {
            UserDefaults.standard.set(
                debugPremiumAccessMode.rawValue,
                forKey: Self.debugPremiumAccessModeKey
            )
            updatePremiumAccess(
                isEnabled: debugPremiumAccessMode.resolvesAccess(
                    revenueCatIsPremium: hasRevenueCatPremiumEntitlement
                )
            )
        }
    }
    private var hasRevenueCatPremiumEntitlement = false
#endif
    private let entitlementId = "pro"

    private var pendingAction: (() -> Void)?
    private var customerInfoTask: Task<Void, Never>?
    private var entitlementExpirationTask: Task<Void, Never>?
    private var subscriptionRefreshTask: Task<Void, Never>?

    private init() {
#if DEBUG
        updatePremiumAccess(
            isEnabled: debugPremiumAccessMode.resolvesAccess(revenueCatIsPremium: false)
        )
#endif
        if let customerInfo = Purchases.shared.cachedCustomerInfo {
            apply(customerInfo: customerInfo)
        }
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
        print("🔄 Restoring purchases...")
#endif
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            apply(customerInfo: customerInfo)
#if DEBUG
            print("✅ Purchases restored. Premium: \(self.isPremium)")
#endif
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
        if let subscriptionRefreshTask {
            await subscriptionRefreshTask.value
            return
        }

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

    /// Refreshes RevenueCat and imports purchases redeemed outside the app.
    func refreshSubscriptionStatus() async {
        if let subscriptionRefreshTask {
            await subscriptionRefreshTask.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performSubscriptionRefresh()
        }

        subscriptionRefreshTask = task
        await task.value
        subscriptionRefreshTask = nil
    }

    private func performSubscriptionRefresh() async {
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            let customerInfo = try await fetchCustomerInfo()
            apply(customerInfo: customerInfo)

            guard !hasActivePremiumEntitlement(in: customerInfo) else {
                return
            }
        } catch {
            print("⚠️ Error refreshing subscription status: \(error)")
        }

        do {
            let customerInfo = try await Purchases.shared.syncPurchases()
            apply(customerInfo: customerInfo)
#if DEBUG
            print("✅ External purchases synced. Premium: \(self.isPremium)")
#endif
        } catch {
            print("⚠️ Error syncing external purchases: \(error)")
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
        try await Purchases.shared.customerInfo()
    }

    private func apply(customerInfo: CustomerInfo) {
        let hasPremiumEntitlement = hasActivePremiumEntitlement(in: customerInfo)
#if DEBUG
        hasRevenueCatPremiumEntitlement = hasPremiumEntitlement
        updatePremiumAccess(
            isEnabled: debugPremiumAccessMode.resolvesAccess(
                revenueCatIsPremium: hasPremiumEntitlement
            )
        )
#else
        updatePremiumAccess(isEnabled: hasPremiumEntitlement)
#endif
        updateEntitlementInfo(from: customerInfo)
    }

    private func hasActivePremiumEntitlement(in customerInfo: CustomerInfo) -> Bool {
        customerInfo.entitlements.active[entitlementId] != nil
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
        scheduleEntitlementRefresh(at: entitlement?.expirationDate)
    }

    private func scheduleEntitlementRefresh(at expirationDate: Date?) {
        entitlementExpirationTask?.cancel()

        guard let expirationDate else {
            return
        }

        let refreshDelay = expirationDate.timeIntervalSinceNow

        guard refreshDelay > 0 else {
            return
        }

        entitlementExpirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(refreshDelay))
                guard let self else { return }

                let customerInfo = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
                self.apply(customerInfo: customerInfo)
            } catch is CancellationError {
                return
            } catch {
                print("⚠️ Error refreshing expired subscription: \(error)")
            }
        }
    }

}
