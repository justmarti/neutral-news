//
//  DeepLinkService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 24/7/25.
//

import Foundation

struct DeepLinkService {
    private static let shareHost = "share.getfacts.app"

    struct DeepLinkData: Equatable {
        let newsId: String
    }

    static func parseDeepLink(_ url: URL) -> DeepLinkData? {
#if DEBUG
        print("🔍 Processing deep link: \(url)")
#endif

        guard let newsId = extractNewsId(from: url), !newsId.isEmpty else {
#if DEBUG
            print("❌ No news ID found in: \(url)")
#endif
            return nil
        }

        let deepLinkData = DeepLinkData(newsId: newsId)

#if DEBUG
        print("✅ Valid deep link - newsId: \(deepLinkData.newsId)")
#endif
        return deepLinkData
    }

    static func parseNotificationPayload(_ userInfo: [AnyHashable: Any]) -> DeepLinkData? {
        if let deepLink = userInfo["deep_link"] as? String,
           let url = URL(string: deepLink),
           let parsedDeepLink = parseDeepLink(url) {
            return parsedDeepLink
        }

        if let newsId = userInfo["news_id"] as? String,
           !newsId.isEmpty {
            return DeepLinkData(newsId: newsId)
        }

        return nil
    }

    private static func extractNewsId(from url: URL) -> String? {
        if url.scheme == "neutralnews" {
            // Custom scheme: neutralnews://abc123
            return normalizedNewsId(url.host)
        }

        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == shareHost
        else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if pathComponents.count == 2,
           pathComponents[0] == "news" {
            return normalizedNewsId(pathComponents[1])
        }

        if pathComponents.count == 3,
           pathComponents[0] == "us",
           pathComponents[1] == "news" {
            return normalizedNewsId(pathComponents[2])
        }

        return nil
    }

    private static func normalizedNewsId(_ value: String?) -> String? {
        guard let value else { return nil }
        let decodedValue = value.removingPercentEncoding ?? value
        return decodedValue.isEmpty ? nil : decodedValue
    }

    static func generateShareURL(
        for news: NeutralNews,
        region: ContentRegion = ContentRegionProvider().currentRegion
    ) -> URL {
        let path: String

        switch region {
        case .us:
            path = "/us/news/\(news.id)"
        case .es:
            path = "/news/\(news.id)"
        }

        let shareURL = "https://share.getfacts.app\(path)"
        return URL(string: shareURL) ?? URL(string: "https://apps.apple.com/app/id6748583935")!
    }
}
