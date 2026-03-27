import Foundation
import Testing
@testable import NeutralNews

@Suite("Deep Link Service Tests")
struct DeepLinkServiceTests {

    @Test("Parses legacy Spain share URL")
    func parsesLegacySpainShareURL() {
        let url = URL(string: "https://share.getfacts.app/news/story-123")!

        let deepLink = DeepLinkService.parseDeepLink(url)

        #expect(deepLink == .init(newsId: "story-123", region: .es))
    }

    @Test("Parses country-scoped share URL")
    func parsesCountryScopedShareURL() {
        let url = URL(string: "https://share.getfacts.app/us/news/story-456")!

        let deepLink = DeepLinkService.parseDeepLink(url)

        #expect(deepLink == .init(newsId: "story-456", region: .us))
    }

    @Test("Parses percent-encoded identifiers")
    func parsesPercentEncodedIdentifiers() {
        let url = URL(string: "https://share.getfacts.app/news/story%20with%20spaces")!

        let deepLink = DeepLinkService.parseDeepLink(url)

        #expect(deepLink == .init(newsId: "story with spaces", region: .es))
    }

    @Test("Parses custom-scheme deep link with region in host")
    func parsesCustomSchemeRegionHost() {
        let url = URL(string: "neutralnews://us/news/story-789")!

        let deepLink = DeepLinkService.parseDeepLink(url)

        #expect(deepLink == .init(newsId: "story-789", region: .us))
    }

    @Test("Parses custom-scheme deep link with region query parameter")
    func parsesCustomSchemeRegionQueryParameter() {
        let url = URL(string: "neutralnews://story-789?region=us")!

        let deepLink = DeepLinkService.parseDeepLink(url)

        #expect(deepLink == .init(newsId: "story-789", region: .us))
    }

    @Test("Parses notification payload with lowercase region")
    func parsesNotificationPayloadWithLowercaseRegion() {
        let payload: [AnyHashable: Any] = [
            "news_id": "story-987",
            "region": "us"
        ]

        let deepLink = DeepLinkService.parseNotificationPayload(payload)

        #expect(deepLink == .init(newsId: "story-987", region: .us))
    }

    @Test("Notification payload prefers deep link over fallback fields")
    func notificationPayloadPrefersDeepLink() {
        let payload: [AnyHashable: Any] = [
            "deep_link": "https://share.getfacts.app/news/story-456",
            "news_id": "story-987",
            "region": "us"
        ]

        let deepLink = DeepLinkService.parseNotificationPayload(payload)

        #expect(deepLink == .init(newsId: "story-456", region: .es))
    }

    @Test("Notification payload falls back to news identifier when deep link is invalid")
    func notificationPayloadFallsBackToNewsIdentifierWhenDeepLinkIsInvalid() {
        let payload: [AnyHashable: Any] = [
            "deep_link": "not a valid url",
            "news_id": "story-987",
            "region": "us"
        ]

        let deepLink = DeepLinkService.parseNotificationPayload(payload)

        #expect(deepLink == .init(newsId: "story-987", region: .us))
    }

    @Test("Rejects unsupported host")
    func rejectsUnsupportedHost() {
        let url = URL(string: "https://example.com/us/news/story-456")!

        let deepLink = DeepLinkService.parseDeepLink(url)

        #expect(deepLink == nil)
    }

    @Test("Rejects unsupported path shape")
    func rejectsUnsupportedPathShape() {
        let url = URL(string: "https://share.getfacts.app/us/news/story-456/extra")!

        let deepLink = DeepLinkService.parseDeepLink(url)

        #expect(deepLink == nil)
    }

    @Test("Rejects empty custom-scheme identifier")
    func rejectsEmptyCustomSchemeIdentifier() {
        let url = URL(string: "neutralnews://")!

        let deepLink = DeepLinkService.parseDeepLink(url)

        #expect(deepLink == nil)
    }

    @Test("Generates Spain share URL without country prefix")
    func generatesSpainShareURL() {
        let url = DeepLinkService.generateShareURL(for: .mock, region: .es)

        #expect(url.absoluteString == "https://share.getfacts.app/news/mock-id")
    }

    @Test("Generates United States share URL with country prefix")
    func generatesUnitedStatesShareURL() {
        let url = DeepLinkService.generateShareURL(for: .mock, region: .us)

        #expect(url.absoluteString == "https://share.getfacts.app/us/news/mock-id")
    }
}
