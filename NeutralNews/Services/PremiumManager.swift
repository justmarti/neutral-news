//
//  PremiumManager.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 23/9/25.
//

import Foundation
import RevenueCat
import Observation

@Observable
final class PremiumManager {
    static let shared = PremiumManager()

    private(set) var isPremium = false
    private(set) var isLoading = false

    private init() {
         checkPremiumStatus()
         setupSubscriptionStatusListener()
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

                self?.isPremium = info?.entitlements.active.isEmpty == false
                print("✅ Premium status: \(self?.isPremium ?? false)")
            }
        }
    }

    private func setupSubscriptionStatusListener() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RCPurchaserInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkPremiumStatus()
        }
    }

    // MARK: - Premium Actions

    func requirePremium(for feature: String = "") {
        if !isPremium {
            NotificationCenter.default.post(name: .showPaywall, object: feature)
        }
    }

    // MARK: - Purchase Actions

    func restorePurchases() async throws {
        let customerInfo = try await Purchases.shared.restorePurchases()
        await MainActor.run {
            self.isPremium = !customerInfo.entitlements.active.isEmpty
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let showPaywall = Notification.Name("ShowPaywall")
}
