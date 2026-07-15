//
//  HomeScreenQuickActionService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/26.
//

import UIKit
import Observation

enum HomeScreenQuickAction: String, CaseIterable {
    case search = "dev.itram.news.search"
    case savedNews = "dev.itram.news.saved"
    case randomNews = "dev.itram.news.random"

    var shortcutItem: UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: rawValue,
            localizedTitle: title,
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: systemImageName),
            userInfo: nil
        )
    }

    private var title: String {
        switch self {
        case .search:
            String(localized: "Search")
        case .savedNews:
            String(localized: "Saved articles", defaultValue: "Saved")
        case .randomNews:
            String(localized: "Random Article")
        }
    }

    private var systemImageName: String {
        switch self {
        case .search:
            "magnifyingglass"
        case .savedNews:
            "bookmark"
        case .randomNews:
            "shuffle"
        }
    }
}

@MainActor
@Observable
final class HomeScreenQuickActionService {
    static let shared = HomeScreenQuickActionService()

    private(set) var pendingAction: HomeScreenQuickAction?

    private init() {}

    func configureShortcutItems(for application: UIApplication) {
        application.shortcutItems = HomeScreenQuickAction.allCases.map(\.shortcutItem)
    }

    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = HomeScreenQuickAction(rawValue: shortcutItem.type) else {
            return false
        }

        pendingAction = action
        return true
    }

    func consumePendingAction() -> HomeScreenQuickAction? {
        defer { pendingAction = nil }
        return pendingAction
    }
}

@MainActor
final class HomeScreenQuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let shortcutItem = connectionOptions.shortcutItem else { return }
        _ = HomeScreenQuickActionService.shared.handle(shortcutItem)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let handled = HomeScreenQuickActionService.shared.handle(shortcutItem)
        completionHandler(handled)
    }
}
