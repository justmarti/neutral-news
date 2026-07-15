//
//  SavedNews+SwiftData.swift
//  NeutralNews
//

import Foundation
import SwiftData

enum SavedNewsRegionScope: String {
    case legacy = "LEGACY"
}

enum SavedNewsType: String, CaseIterable {
    case neutralNews = "neutral_news"
    case news = "news"
}

private struct SavedRelatedNewsSnapshotSwiftData: Codable {
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

private struct SavedNewsSourcesPayloadSwiftData: Codable {
    let sourceIds: [String]
    let relatedNews: [SavedRelatedNewsSnapshotSwiftData]?
}

@Model
final class SavedNewsItem {
    var storageKey: String = ""
    var newsId: String = ""
    var newsType: String = ""
    var regionRaw: String = ""
    var createdAt: Date = Date()
    var neutralTitle: String = ""
    var neutralDescription: String = ""
    var category: String = ""
    var relevance: Int = 0
    var imageUrl: String = ""
    var imageMedium: String = ""
    var originalDate: Date = Date()
    var originalCreatedAt: Date = Date()
    var originalUpdatedAt: Date = Date()
    var group: Int = 0
    var sourceIdsPayload: String = "[]"

    init(
        newsId: String,
        newsType: String,
        regionRaw: String,
        createdAt: Date,
        neutralTitle: String,
        neutralDescription: String,
        category: String,
        relevance: Int,
        imageUrl: String,
        imageMedium: String,
        originalDate: Date,
        originalCreatedAt: Date,
        originalUpdatedAt: Date,
        group: Int,
        sourceIdsPayload: String
    ) {
        self.storageKey = Self.storageKey(newsId: newsId, regionRaw: regionRaw)
        self.newsId = newsId
        self.newsType = newsType
        self.regionRaw = regionRaw
        self.createdAt = createdAt
        self.neutralTitle = neutralTitle
        self.neutralDescription = neutralDescription
        self.category = category
        self.relevance = relevance
        self.imageUrl = imageUrl
        self.imageMedium = imageMedium
        self.originalDate = originalDate
        self.originalCreatedAt = originalCreatedAt
        self.originalUpdatedAt = originalUpdatedAt
        self.group = group
        self.sourceIdsPayload = sourceIdsPayload
    }

    convenience init(from neutralNews: NeutralNews, relatedNews: [News], regionRaw: String, createdAt: Date = Date()) {
        self.init(
            newsId: neutralNews.id,
            newsType: SavedNewsType.neutralNews.rawValue,
            regionRaw: regionRaw,
            createdAt: createdAt,
            neutralTitle: neutralNews.neutralTitle,
            neutralDescription: neutralNews.neutralDescription,
            category: neutralNews.category,
            relevance: neutralNews.relevance,
            imageUrl: neutralNews.imageUrl,
            imageMedium: neutralNews.imageMedium,
            originalDate: neutralNews.date,
            originalCreatedAt: neutralNews.createdAt,
            originalUpdatedAt: neutralNews.updatedAt,
            group: neutralNews.group,
            sourceIdsPayload: Self.encodeStoredSources(
                sourceIds: neutralNews.sourceIds,
                relatedNews: relatedNews
            )
        )
    }

    convenience init(from news: News, regionRaw: String, createdAt: Date = Date()) {
        self.init(
            newsId: news.id,
            newsType: SavedNewsType.news.rawValue,
            regionRaw: regionRaw,
            createdAt: createdAt,
            neutralTitle: news.title,
            neutralDescription: news.description,
            category: news.category,
            relevance: news.neutralScore,
            imageUrl: news.imageUrl ?? "",
            imageMedium: news.publisher,
            originalDate: news.pubDate,
            originalCreatedAt: news.createdAt,
            originalUpdatedAt: news.updatedAt,
            group: news.group,
            sourceIdsPayload: Self.encodeStoredSources(sourceIds: [news.id], relatedNews: [news])
        )
    }

    static func storageKey(newsId: String, regionRaw: String) -> String {
        "\(regionRaw)|\(newsId)"
    }

    static func encodeStoredSources(sourceIds: [String], relatedNews: [News]) -> String {
        let payload = SavedNewsSourcesPayloadSwiftData(
            sourceIds: sourceIds,
            relatedNews: relatedNews.map(SavedRelatedNewsSnapshotSwiftData.init(from:))
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

    static func decodeStoredSourceIds(from payloadString: String) -> [String] {
        guard let jsonData = payloadString.data(using: .utf8) else {
            return []
        }

        if let decodedPayload = try? JSONDecoder().decode(SavedNewsSourcesPayloadSwiftData.self, from: jsonData) {
            return decodedPayload.sourceIds
        }

        if let decodedArray = try? JSONDecoder().decode([String].self, from: jsonData) {
            return decodedArray
        }

        return []
    }

    static func decodeStoredRelatedNews(from payloadString: String) -> [News] {
        guard let jsonData = payloadString.data(using: .utf8),
              let decodedPayload = try? JSONDecoder().decode(SavedNewsSourcesPayloadSwiftData.self, from: jsonData),
              let snapshots = decodedPayload.relatedNews else {
            return []
        }

        return snapshots.map { $0.toNews() }
    }

    func toNeutralNews() -> NeutralNews {
        let sourceIds = Self.decodeStoredSourceIds(from: sourceIdsPayload)

        return NeutralNews(
            id: newsId,
            neutralTitle: neutralTitle,
            neutralDescription: neutralDescription,
            category: category,
            relevance: relevance,
            imageUrl: imageUrl,
            imageMedium: imageMedium,
            date: originalDate,
            createdAt: originalCreatedAt,
            updatedAt: originalUpdatedAt,
            group: group,
            sourceIds: sourceIds
        )
    }

    func savedRelatedNews() -> [News] {
        Self.decodeStoredRelatedNews(from: sourceIdsPayload)
    }
}

enum SavedNewsSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SavedNewsItem.self]
    }
}

enum SavedNewsMigrationPlan: SchemaMigrationPlan {
    // Keep this plan active even with a single schema so adding V2/V3 is explicit and safe.
    static var schemas: [any VersionedSchema.Type] {
        [SavedNewsSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
