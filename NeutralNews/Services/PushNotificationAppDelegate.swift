//
//  PushNotificationAppDelegate.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 8/3/26.
//

import Foundation
import UIKit
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@MainActor
final class PushNotificationAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        PushNotificationService.shared.remoteNotificationRegistrar = {
            application.registerForRemoteNotifications()
        }

#if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
#endif

        HomeScreenQuickActionService.shared.configureShortcutItems(for: application)

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = HomeScreenQuickActionSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.handleDidRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
#if DEBUG
        print("❌ APNs registration failed: \(error)")
#endif
    }
}

extension PushNotificationAppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
#if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
#endif
        return []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
#if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(response.notification.request.content.userInfo)
#endif
        PushNotificationService.shared.handleNotificationResponse(userInfo: response.notification.request.content.userInfo)
    }
}

#if canImport(FirebaseMessaging)
extension PushNotificationAppDelegate: @preconcurrency MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        PushNotificationService.shared.handleDidReceiveRegistrationToken(fcmToken)
    }
}
#endif
