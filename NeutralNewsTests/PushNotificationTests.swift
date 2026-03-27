//
//  PushNotificationTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 8/3/26.
//

import Foundation
import Testing
@testable import NeutralNews

@Suite("Push Notification Tests")
struct PushNotificationTests {
    @Test("Top story topic uses region suffix")
    func topStoryTopicUsesRegionSuffix() {
        #if DEBUG
        #expect(PushNotificationTopic.news(for: .es) == "news_es_dev")
        #expect(PushNotificationTopic.news(for: .us) == "news_us_dev")
        #else
        #expect(PushNotificationTopic.news(for: .es) == "news_es")
        #expect(PushNotificationTopic.news(for: .us) == "news_us")
        #endif
    }

    @Test("Notification payload supports deep links")
    func notificationPayloadSupportsDeepLinks() {
        let payload: [AnyHashable: Any] = [
            "deep_link": "neutralnews://abc123"
        ]

        let deepLink = DeepLinkService.parseNotificationPayload(payload)

        #expect(deepLink == DeepLinkService.DeepLinkData(newsId: "abc123", region: nil))
    }

    @Test("Notification payload falls back to news identifier")
    func notificationPayloadFallsBackToNewsIdentifier() {
        let payload: [AnyHashable: Any] = [
            "news_id": "story-42"
        ]

        let deepLink = DeepLinkService.parseNotificationPayload(payload)

        #expect(deepLink == DeepLinkService.DeepLinkData(newsId: "story-42", region: nil))
    }
}
