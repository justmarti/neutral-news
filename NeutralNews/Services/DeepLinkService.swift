//
//  DeepLinkService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 24/7/25.
//

import Foundation

struct DeepLinkService {

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

    private static func extractNewsId(from url: URL) -> String? {
        if url.scheme == "neutralnews" {
            // Custom scheme: neutralnews://abc123
            return url.host
        } else {
            // Universal Link: https://getfacts.app/abc123
            return String(url.path.dropFirst()) // Remove leading slash
        }
    }

    static func generateShareURL(for news: NeutralNews) -> URL {
        let shareURL = "https://getfacts.app/\(news.id)"
        return URL(string: shareURL) ?? URL(string: "https://apps.apple.com/app/neutral-news/idXXXXXXXXX")!
    }
}