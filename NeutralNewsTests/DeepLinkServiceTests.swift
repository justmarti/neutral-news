import Foundation
import Testing
@testable import NeutralNews

@Suite("DeepLinkService Tests")
struct DeepLinkServiceTests {

    @Test("Parses legacy share URL")
    func parsesLegacyShareURL() {
        let url = URL(string: "https://share.getfacts.app/news/story-123")!

        let deepLinkData = DeepLinkService.parseDeepLink(url)

        #expect(deepLinkData == .init(newsId: "story-123", region: .es))
    }

    @Test("Parses country-scoped share URL")
    func parsesCountryScopedShareURL() {
        let url = URL(string: "https://share.getfacts.app/us/news/story-456")!

        let deepLinkData = DeepLinkService.parseDeepLink(url)

        #expect(deepLinkData == .init(newsId: "story-456", region: .us))
    }

    @Test("Parses custom scheme deep link")
    func parsesCustomSchemeDeepLink() {
        let url = URL(string: "neutralnews://story-789")!

        let deepLinkData = DeepLinkService.parseDeepLink(url)

        #expect(deepLinkData == .init(newsId: "story-789", region: nil))
    }

    @Test("Parses notification payload with deep link")
    func parsesNotificationPayloadWithDeepLink() {
        let payload: [AnyHashable: Any] = [
            "deep_link": "https://share.getfacts.app/us/news/story-456"
        ]

        let deepLinkData = DeepLinkService.parseNotificationPayload(payload)

        #expect(deepLinkData == .init(newsId: "story-456", region: .us))
    }

    @Test("Parses notification payload with news ID and region")
    func parsesNotificationPayloadWithNewsIdAndRegion() {
        let payload: [AnyHashable: Any] = [
            "news_id": "story-987",
            "region": "es"
        ]

        let deepLinkData = DeepLinkService.parseNotificationPayload(payload)

        #expect(deepLinkData == .init(newsId: "story-987", region: .es))
    }

    @Test("Rejects unsupported host")
    func rejectsUnsupportedHost() {
        let url = URL(string: "https://example.com/us/news/story-456")!

        let deepLinkData = DeepLinkService.parseDeepLink(url)

        #expect(deepLinkData == nil)
    }

    @Test("Rejects unsupported path")
    func rejectsUnsupportedPath() {
        let url = URL(string: "https://share.getfacts.app/us/news/story-456/extra")!

        let deepLinkData = DeepLinkService.parseDeepLink(url)

        #expect(deepLinkData == nil)
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
