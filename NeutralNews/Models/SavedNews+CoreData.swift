//
//  SavedNews+CoreData.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 23/9/25.
//

import Foundation
import CoreData

extension SavedNews {

    convenience init(from neutralNews: NeutralNews, context: NSManagedObjectContext) {
        self.init(context: context)
        self.newsId = neutralNews.id
        self.newsType = SavedNewsType.neutralNews.rawValue
        self.createdAt = Date()
        self.neutralTitle = neutralNews.neutralTitle
        self.neutralDescription = neutralNews.neutralDescription
        self.category = neutralNews.category
        self.relevance = Int32(neutralNews.relevance)
        self.imageUrl = neutralNews.imageUrl
        self.imageMedium = neutralNews.imageMedium
        self.originalDate = neutralNews.date
        self.originalCreatedAt = neutralNews.createdAt
        self.originalUpdatedAt = neutralNews.updatedAt
        self.group = Int32(neutralNews.group)
        // Convert array to JSON string
        if let jsonData = try? JSONEncoder().encode(neutralNews.sourceIds),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.sourceIds = jsonString
        } else {
            self.sourceIds = "[]"
        }
    }

    convenience init(from news: News, context: NSManagedObjectContext) {
        self.init(context: context)
        self.newsId = news.id
        self.newsType = SavedNewsType.news.rawValue
        self.createdAt = Date()
        self.neutralTitle = news.title
        self.neutralDescription = news.description
        self.category = news.category
        self.relevance = Int32(news.neutralScore)
        self.imageUrl = news.imageUrl ?? ""
        self.imageMedium = news.sourceMedium.rawValue
        self.originalDate = news.pubDate
        self.originalCreatedAt = news.createdAt
        self.originalUpdatedAt = news.updatedAt
        self.group = Int32(news.group)
        // Convert array to JSON string
        if let jsonData = try? JSONEncoder().encode([news.id]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.sourceIds = jsonString
        } else {
            self.sourceIds = "[\"" + news.id + "\"]"
        }
    }

    func toNeutralNews() -> NeutralNews? {
        guard let newsId = newsId,
              let neutralTitle = neutralTitle,
              let neutralDescription = neutralDescription,
              let category = category,
              let imageUrl = imageUrl,
              let imageMedium = imageMedium,
              let originalDate = originalDate,
              let originalCreatedAt = originalCreatedAt,
              let originalUpdatedAt = originalUpdatedAt,
              let sourceIdsString = sourceIds else {
            return nil
        }

        // Convert JSON string back to array
        let sourceIdsArray: [String]
        if let jsonData = sourceIdsString.data(using: .utf8),
           let decodedArray = try? JSONDecoder().decode([String].self, from: jsonData) {
            sourceIdsArray = decodedArray
        } else {
            sourceIdsArray = []
        }

        return NeutralNews(
            id: newsId,
            neutralTitle: neutralTitle,
            neutralDescription: neutralDescription,
            category: category,
            relevance: Int(relevance),
            imageUrl: imageUrl,
            imageMedium: imageMedium,
            date: originalDate,
            createdAt: originalCreatedAt,
            updatedAt: originalUpdatedAt,
            group: Int(group),
            sourceIds: sourceIdsArray
        )
    }
}

enum SavedNewsType: String, CaseIterable {
    case neutralNews = "neutral_news"
    case news = "news"
}