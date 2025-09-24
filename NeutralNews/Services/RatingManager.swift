//
//  RatingManager.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 25/09/25.
//

import SwiftUI
import StoreKit

@Observable
@MainActor
final class RatingManager {
    static let shared = RatingManager()

    private let defaults = UserDefaults.standard
    private let minimumLaunchCount = 3
    private let minimumDaysSinceInstall = 7
    private let minimumDaysBetweenPrompts = 365

    private enum Keys {
        static let launchCount = "app_launch_count"
        static let firstLaunchDate = "first_launch_date"
        static let lastRatingPromptDate = "last_rating_prompt_date"
        static let hasRatedCurrentVersion = "has_rated_current_version"
        static let newsReadCount = "news_read_count"
        static let savedNewsCount = "saved_news_count"
    }

    private init() {}

    func incrementLaunchCount() {
        let currentCount = defaults.integer(forKey: Keys.launchCount)
        defaults.set(currentCount + 1, forKey: Keys.launchCount)

        if defaults.object(forKey: Keys.firstLaunchDate) == nil {
            defaults.set(Date(), forKey: Keys.firstLaunchDate)
        }
    }

    func incrementNewsReadCount() {
        let currentCount = defaults.integer(forKey: Keys.newsReadCount)
        defaults.set(currentCount + 1, forKey: Keys.newsReadCount)
    }

    func incrementSavedNewsCount() {
        let currentCount = defaults.integer(forKey: Keys.savedNewsCount)
        defaults.set(currentCount + 1, forKey: Keys.savedNewsCount)
    }

    private var shouldRequestRating: Bool {
        guard !defaults.bool(forKey: Keys.hasRatedCurrentVersion) else { return false }

        let launchCount = defaults.integer(forKey: Keys.launchCount)
        guard launchCount >= minimumLaunchCount else { return false }

        guard let firstLaunchDate = defaults.object(forKey: Keys.firstLaunchDate) as? Date else { return false }
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: Date()).day ?? 0
        guard daysSinceInstall >= minimumDaysSinceInstall else { return false }

        if let lastPromptDate = defaults.object(forKey: Keys.lastRatingPromptDate) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPromptDate, to: Date()).day ?? 0
            guard daysSinceLastPrompt >= minimumDaysBetweenPrompts else { return false }
        }

        return true
    }

    func requestRatingIfAppropriate() {
        guard shouldRequestRating else { return }

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                AppStore.requestReview(in: windowScene)
                defaults.set(Date(), forKey: Keys.lastRatingPromptDate)
            }
        }
    }

    func requestRatingAfterPositiveInteraction() {
        guard shouldRequestRating else { return }

        let newsReadCount = defaults.integer(forKey: Keys.newsReadCount)
        let savedNewsCount = defaults.integer(forKey: Keys.savedNewsCount)

        if newsReadCount >= 5 || savedNewsCount >= 3 {
            requestRatingIfAppropriate()
        }
    }
}