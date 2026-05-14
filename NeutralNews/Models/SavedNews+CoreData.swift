//
//  SavedNews+CoreData.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 23/9/25.
//

import Foundation
import CoreData

private struct SavedRelatedNewsSnapshot: Codable {
    let id: String
    let title: String
    let description: String
    let scrappedDescription: String?
    let category: String
    let imageUrl: String?
    let link: String
    let pubDate: Date
    let createdAt: Date
    let updatedAt: Date
    let publisher: String
    let neutralScore: Int
    let group: Int

    init(from news: News) {
        self.id = news.id
        self.title = news.title
        self.description = news.description
        self.scrappedDescription = news.scrappedDescription
        self.category = news.category
        self.imageUrl = news.imageUrl
        self.link = news.link
        self.pubDate = news.pubDate
        self.createdAt = news.createdAt
        self.updatedAt = news.updatedAt
        self.publisher = news.publisher
        self.neutralScore = news.neutralScore
        self.group = news.group
    }

    func toNews() -> News {
        News(
            id: id,
            title: title,
            description: description,
            scrappedDescription: scrappedDescription,
            category: category,
            imageUrl: imageUrl,
            link: link,
            pubDate: pubDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            publisher: publisher,
            neutralScore: neutralScore,
            group: group,
            embedding: []
        )
    }
}

private struct SavedNewsSourcesPayload: Codable {
    let sourceIds: [String]
    let relatedNews: [SavedRelatedNewsSnapshot]?
}

extension SavedNews {

    static func encodeStoredSources(sourceIds: [String], relatedNews: [News]) -> String {
        let payload = SavedNewsSourcesPayload(
            sourceIds: sourceIds,
            relatedNews: relatedNews.map(SavedRelatedNewsSnapshot.init(from:))
        )

        if let jsonData = try? JSONEncoder().encode(payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        if let jsonData = try? JSONEncoder().encode(sourceIds),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "[]"
    }

    static func decodeStoredSourceIds(from sourceIdsString: String) -> [String] {
        guard let jsonData = sourceIdsString.data(using: .utf8) else {
            return []
        }

        if let decodedPayload = try? JSONDecoder().decode(SavedNewsSourcesPayload.self, from: jsonData) {
            return decodedPayload.sourceIds
        }

        if let decodedArray = try? JSONDecoder().decode([String].self, from: jsonData) {
            return decodedArray
        }

        return []
    }

    static func decodeStoredRelatedNews(from sourceIdsString: String) -> [News] {
        guard let jsonData = sourceIdsString.data(using: .utf8),
              let decodedPayload = try? JSONDecoder().decode(SavedNewsSourcesPayload.self, from: jsonData),
              let snapshots = decodedPayload.relatedNews else {
            return []
        }

        return snapshots.map { $0.toNews() }
    }

    convenience init(from neutralNews: NeutralNews, relatedNews: [News], context: NSManagedObjectContext) {
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
        self.sourceIds = SavedNews.encodeStoredSources(
            sourceIds: neutralNews.sourceIds,
            relatedNews: relatedNews
        )
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
        self.imageMedium = news.publisher
        self.originalDate = news.pubDate
        self.originalCreatedAt = news.createdAt
        self.originalUpdatedAt = news.updatedAt
        self.group = Int32(news.group)
        self.sourceIds = SavedNews.encodeStoredSources(sourceIds: [news.id], relatedNews: [news])
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

        let sourceIdsArray = SavedNews.decodeStoredSourceIds(from: sourceIdsString)

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

    func savedRelatedNews() -> [News] {
        guard let sourceIdsString = sourceIds else {
            return []
        }

        return SavedNews.decodeStoredRelatedNews(from: sourceIdsString)
    }
}

enum SavedNewsType: String, CaseIterable {
    case neutralNews = "neutral_news"
    case news = "news"
}
