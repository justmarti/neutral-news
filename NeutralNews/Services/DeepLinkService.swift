//
//  DeepLinkService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 24/7/25.
//

import Foundation

struct DeepLinkService {
    
    struct DeepLinkData: Equatable {
        let group: Int
        let date: Date
    }
    
    static func parseDeepLink(_ url: URL) -> DeepLinkData? {
#if DEBUG
        print("🔍 Processing deep link: \(url)")
#endif
        
        let queryItems = extractQueryItems(from: url)
        guard let queryItems = queryItems else {
#if DEBUG
            print("❌ No parameters found in: \(url)")
#endif
            return nil
        }
        
        guard let deepLinkData = parseQueryItems(queryItems) else {
#if DEBUG
            print("❌ Missing or invalid parameters")
#endif
            return nil
        }
        
#if DEBUG
        print("✅ Valid deep link - group: \(deepLinkData.group), date: \(deepLinkData.date)")
#endif
        return deepLinkData
    }
    
    private static func extractQueryItems(from url: URL) -> [URLQueryItem]? {
        if url.scheme == "neutralnews" {
            // Custom scheme: neutralnews://news?group=123&date=2025-07-23
            return URLComponents(string: url.absoluteString)?.queryItems
        } else {
            // Universal Link: https://itram.dev/neutralnews?group=123&date=2025-07-23
            return URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems
        }
    }
    
    private static func parseQueryItems(_ queryItems: [URLQueryItem]) -> DeepLinkData? {
        var group: Int?
        var dateString: String?
        
        for item in queryItems {
            switch item.name {
            case "group":
                group = Int(item.value ?? "")
            case "date":
                dateString = item.value
            default:
                break
            }
        }
        
        guard let group = group,
              let dateString = dateString,
              let date = parseDate(from: dateString) else {
            return nil
        }
        
        return DeepLinkData(group: group, date: date)
    }
    
    private static func parseDate(from dateString: String) -> Date? {
        let dateParts = dateString.split(separator: "-")
        guard dateParts.count == 3,
              let year = Int(dateParts[0]),
              let month = Int(dateParts[1]),
              let day = Int(dateParts[2]) else {
            return nil
        }
        
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0

        return Calendar.current.date(from: dateComponents)
    }
    
    static func generateShareURL(for news: NeutralNews) -> URL {
        let baseURL = "https://itram.dev/neutralnews"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: news.date)
        
        let shareURL = "\(baseURL)?group=\(news.group)&date=\(dateString)"
        return URL(string: shareURL) ?? URL(string: "https://apps.apple.com/app/neutral-news/idXXXXXXXXX")!
    }
}
