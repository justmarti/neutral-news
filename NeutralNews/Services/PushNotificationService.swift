//
//  PushNotificationService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 8/3/26.
//

import Foundation
import Observation
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

enum PushNotificationTopic {
    static func news(for region: ContentRegion) -> String {
        "news_\(region.rawValue.lowercased())\(suffix)"
    }

    private static var suffix: String {
        #if DEBUG
        return "_dev"
        #else
        return ""
        #endif
    }
}

@Observable
@MainActor
final class PushNotificationService {
    static let shared = PushNotificationService()

    static let didReceiveDeepLinkNotification = Notification.Name("PushNotificationService.didReceiveDeepLink")
    static let deepLinkUserInfoKey = "deepLink"

    private enum Keys {
        static let topStoriesEnabled = "push_top_stories_enabled"
        static let subscribedTopic = "push_subscribed_topic"
    }

    @ObservationIgnored private let userNotificationCenter = UNUserNotificationCenter.current()
    @ObservationIgnored private let regionProvider: ContentRegionProviding
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var remoteNotificationRegistrar: (@MainActor () -> Void)?
    @ObservationIgnored private var hasAPNSToken = false
    @ObservationIgnored private var preferenceChangeTask: Task<Void, Never>?
    @ObservationIgnored private var topicSyncTask: Task<Void, Never>?
    @ObservationIgnored private var isTopicSyncInProgress = false
    @ObservationIgnored private var hasPendingTopicSync = false
    @ObservationIgnored private var isAuthorizationRequestInFlight = false

    var isTopStoriesEnabled: Bool {
        didSet {
            guard isTopStoriesEnabled != oldValue else { return }
            defaults.set(isTopStoriesEnabled, forKey: Keys.topStoriesEnabled)
            schedulePreferenceChange()
        }
    }

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var fcmToken: String?

    private init(
        regionProvider: ContentRegionProviding = ContentRegionProvider(),
        defaults: UserDefaults = .standard
    ) {
        self.regionProvider = regionProvider
        self.defaults = defaults
        self.isTopStoriesEnabled = defaults.bool(forKey: Keys.topStoriesEnabled)
    }

    var currentTopic: String {
        PushNotificationTopic.news(for: regionProvider.currentRegion)
    }

    private var hasStoredTopicSubscription: Bool {
        defaults.string(forKey: Keys.subscribedTopic) != nil
    }

    var isTopStoriesToggleOn: Bool {
        get {
            isTopStoriesEnabled && areNotificationsAuthorized
        }
        set {
            isTopStoriesEnabled = newValue
        }
    }

    var notificationsFooterText: LocalizedStringResource? {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return nil
        case .denied:
            return "Notifications are turned off in Settings."
        case .notDetermined:
            return "Allow notifications to receive alerts."
        @unknown default:
            return nil
        }
    }

    var areNotificationsAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    func configureOnLaunch() {
        Task {
            await refreshAuthorizationStatus()

            if hasStoredTopicSubscription {
                scheduleTopicSync()
            }

            guard isTopStoriesEnabled, areNotificationsAuthorized else { return }
            registerForRemoteNotifications()
        }
    }

    func handleAppDidBecomeActive() {
        Task {
            await refreshAuthorizationStatus()

            if hasStoredTopicSubscription || hasAPNSToken {
                scheduleTopicSync()
            }

            guard isTopStoriesEnabled, areNotificationsAuthorized else { return }
            registerForRemoteNotifications()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await userNotificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func handleDidRegisterForRemoteNotifications(deviceToken: Data) {
        hasAPNSToken = true
#if canImport(FirebaseMessaging)
        #if DEBUG
        Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        #endif
        refreshFCMTokenIfNeeded()
#endif
    }

    func handleDidReceiveRegistrationToken(_ token: String) {
        fcmToken = token

        guard isTopStoriesEnabled, areNotificationsAuthorized else { return }
        scheduleTopicSync()
    }

    func handleNotificationResponse(userInfo: [AnyHashable: Any]) {
        guard let deepLink = DeepLinkService.parseNotificationPayload(userInfo) else { return }
        NotificationCenter.default.post(
            name: Self.didReceiveDeepLinkNotification,
            object: nil,
            userInfo: [Self.deepLinkUserInfoKey: deepLink]
        )
    }

    func handleCompletedOnboarding() {
        Task {
            await requestAuthorizationIfStillUndecided()
        }
    }

    func handleOpenedArticle() {
        Task {
            await requestAuthorizationIfStillUndecided()
        }
    }

    func handleRegionPreferenceChange() {
        guard isTopStoriesEnabled, areNotificationsAuthorized, hasAPNSToken else { return }
        scheduleTopicSync()
    }

    func syncTopicSubscription() async {
        let desiredTopic = isTopStoriesEnabled && areNotificationsAuthorized ? currentTopic : nil
        let previousTopic = defaults.string(forKey: Keys.subscribedTopic)

        if previousTopic == desiredTopic {
            return
        }

        if desiredTopic != nil && !hasAPNSToken {
            return
        }

#if canImport(FirebaseMessaging)
        if let previousTopic, previousTopic != desiredTopic {
            await unsubscribe(from: previousTopic)
        }

        if let desiredTopic {
            await subscribe(to: desiredTopic)
            defaults.set(desiredTopic, forKey: Keys.subscribedTopic)
        } else {
            defaults.removeObject(forKey: Keys.subscribedTopic)
        }
#else
        if let desiredTopic {
            defaults.set(desiredTopic, forKey: Keys.subscribedTopic)
        } else {
            defaults.removeObject(forKey: Keys.subscribedTopic)
        }
#endif
    }

    private func applyTopStoriesPreferenceChange() async {
        if isTopStoriesEnabled {
            let granted = await requestAuthorizationIfNeeded()
            guard granted else {
                isTopStoriesEnabled = false
                return
            }

            registerForRemoteNotifications()
            scheduleTopicSync()
        } else {
            await syncTopicSubscription()
        }
    }

    private func schedulePreferenceChange() {
        preferenceChangeTask?.cancel()
        preferenceChangeTask = Task { [weak self] in
            guard let self else { return }
            await self.applyTopStoriesPreferenceChange()
        }
    }

    private func scheduleTopicSync() {
        hasPendingTopicSync = true

        guard topicSyncTask == nil else { return }

        topicSyncTask = Task { [weak self] in
            guard let self else { return }
            await self.processPendingTopicSyncs()
        }
    }

    private func processPendingTopicSyncs() async {
        guard !isTopicSyncInProgress else { return }
        isTopicSyncInProgress = true
        defer {
            isTopicSyncInProgress = false
            topicSyncTask = nil
        }

        while hasPendingTopicSync {
            hasPendingTopicSync = false
            await syncTopicSubscription()
        }
    }

    private func requestAuthorizationIfStillUndecided() async {
        await refreshAuthorizationStatus()

        guard authorizationStatus == .notDetermined else { return }
        guard !isAuthorizationRequestInFlight else { return }

        isAuthorizationRequestInFlight = true
        defer { isAuthorizationRequestInFlight = false }

        let granted = await requestAuthorizationIfNeeded()
        isTopStoriesEnabled = granted
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await userNotificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
                await refreshAuthorizationStatus()
                return granted
            } catch {
#if DEBUG
                print("❌ Notification authorization request failed: \(error)")
#endif
                await refreshAuthorizationStatus()
                return false
            }
        @unknown default:
            return false
        }
    }

    private func registerForRemoteNotifications() {
        remoteNotificationRegistrar?()
    }

#if canImport(FirebaseMessaging)
    private func refreshFCMTokenIfNeeded() {
        Messaging.messaging().token { [weak self] token, error in
            guard let self else { return }

#if DEBUG
            if let error {
                print("❌ FCM token refresh failed: \(error)")
            }
#endif

            guard let token, !token.isEmpty else { return }

            Task { @MainActor in
                self.handleDidReceiveRegistrationToken(token)
            }
        }
    }

    private func subscribe(to topic: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Messaging.messaging().subscribe(toTopic: topic) { error in
#if DEBUG
                if let error {
                    print("❌ Topic subscription failed for \(topic): \(error)")
                } else {
                    print("✅ Subscribed to topic: \(topic)")
                }
#endif
                continuation.resume()
            }
        }
    }

    private func unsubscribe(from topic: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
#if DEBUG
                if let error {
                    print("❌ Topic unsubscription failed for \(topic): \(error)")
                } else {
                    print("✅ Unsubscribed from topic: \(topic)")
                }
#endif
                continuation.resume()
            }
        }
    }
#endif
}
