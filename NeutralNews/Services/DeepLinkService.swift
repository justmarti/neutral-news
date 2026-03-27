//
//  DeepLinkService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 24/7/25.
//

import Foundation

struct DeepLinkService {
    private static let shareHost = "share.getfacts.app"

    struct DeepLinkData: Equatable, Sendable {
        let newsId: String
        let region: ContentRegion?
    }

    static func parseDeepLink(_ url: URL) -> DeepLinkData? {
#if DEBUG
        print("🔍 Processing deep link: \(url)")
#endif

        guard let deepLinkData = extractDeepLinkData(from: url) else {
#if DEBUG
            print("❌ No news ID found in: \(url)")
#endif
            return nil
        }

#if DEBUG
        print("✅ Valid deep link - newsId: \(deepLinkData.newsId), region: \(deepLinkData.region?.rawValue ?? "current")")
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
            let region = normalizedRegion(userInfo["region"] as? String)
            return DeepLinkData(newsId: newsId, region: region)
        }

        return nil
    }

    private static func extractDeepLinkData(from url: URL) -> DeepLinkData? {
        if url.scheme == "neutralnews" {
            return extractCustomSchemeDeepLinkData(from: url)
        }

        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == shareHost
        else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if pathComponents.count == 2,
           pathComponents[0] == "news" {
            guard let newsId = normalizedNewsId(pathComponents[1]) else { return nil }
            return DeepLinkData(newsId: newsId, region: .es)
        }

        if pathComponents.count == 3,
           pathComponents[0] == "us",
           pathComponents[1] == "news" {
            guard let newsId = normalizedNewsId(pathComponents[2]) else { return nil }
            return DeepLinkData(newsId: newsId, region: .us)
        }

        return nil
    }

    private static func extractCustomSchemeDeepLinkData(from url: URL) -> DeepLinkData? {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if let host = normalizedRegion(url.host),
           pathComponents.count == 2,
           pathComponents[0] == "news",
           let newsId = normalizedNewsId(pathComponents[1]) {
            return DeepLinkData(newsId: newsId, region: host)
        }

        if let newsId = normalizedNewsId(url.host) {
            let region = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "region" })
                .flatMap { normalizedRegion($0.value) }
            return DeepLinkData(newsId: newsId, region: region)
        }

        return nil
    }

    private static func normalizedNewsId(_ value: String?) -> String? {
        guard let value else { return nil }
        let decodedValue = value.removingPercentEncoding ?? value
        return decodedValue.isEmpty ? nil : decodedValue
    }

    private static func normalizedRegion(_ value: String?) -> ContentRegion? {
        guard let value else { return nil }
        return ContentRegion(rawValue: value.uppercased())
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
