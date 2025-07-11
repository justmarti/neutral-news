//
//  CachedNews.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftData

@Model
final class CachedNeutralNews {
    @Attribute(.unique) var id: String
    var neutralTitle: String
    var neutralDescription: String
    var category: String
    var relevance: Int
    var imageUrl: String
    var imageMedium: String
    var date: Date
    var createdAt: Date
    var updatedAt: Date
    var group: Int
    
    // Cache metadata
    var cacheDate: Date
    var dayDate: Date // Start of day for this news
    
    init(from neutralNews: NeutralNews) {
        self.id = neutralNews.id
        self.neutralTitle = neutralNews.neutralTitle
        self.neutralDescription = neutralNews.neutralDescription
        self.category = neutralNews.category
        self.relevance = neutralNews.relevance
        self.imageUrl = neutralNews.imageUrl
        self.imageMedium = neutralNews.imageMedium
        self.date = neutralNews.date
        self.createdAt = neutralNews.createdAt
        self.updatedAt = neutralNews.updatedAt
        self.group = neutralNews.group
        
        self.cacheDate = Date()
        self.dayDate = Calendar.current.startOfDay(for: neutralNews.date)
    }
    
    func toNeutralNews() -> NeutralNews {
        var news = NeutralNews(
            neutralTitle: neutralTitle,
            neutralDescription: neutralDescription,
            category: category,
            relevance: relevance,
            imageUrl: imageUrl,
            imageMedium: imageMedium,
            date: date,
            createdAt: createdAt,
            updatedAt: updatedAt,
            group: group
        )
        news.id = id
        return news
    }
}

@Model
final class CachedNews {
    @Attribute(.unique) var id: String
    var title: String
    var newsDescription: String
    var scrappedDescription: String?
    var category: String
    var imageUrl: String?
    var link: String
    var pubDate: Date
    var createdAt: Date
    var updatedAt: Date
    var sourceMediumRaw: String
    var neutralScore: Int
    var group: Int
    var embedding: Data // Encoded [Double]
    
    // Cache metadata
    var cacheDate: Date
    var dayDate: Date
    
    init(from news: News) {
        self.id = news.id
        self.title = news.title
        self.newsDescription = news.description
        self.scrappedDescription = news.scrappedDescription
        self.category = news.category
        self.imageUrl = news.imageUrl
        self.link = news.link
        self.pubDate = news.pubDate
        self.createdAt = news.createdAt
        self.updatedAt = news.updatedAt
        self.sourceMediumRaw = news.sourceMedium.rawValue
        self.neutralScore = news.neutralScore
        self.group = news.group
        
        // Encode embedding array to Data
        self.embedding = try! JSONEncoder().encode(news.embedding)
        
        self.cacheDate = Date()
        self.dayDate = Calendar.current.startOfDay(for: news.pubDate)
    }
    
    func toNews() -> News? {
        guard let sourceMedium = Media(rawValue: sourceMediumRaw) else { return nil }
        
        // Decode embedding
        let embeddingArray = (try? JSONDecoder().decode([Double].self, from: embedding)) ?? []
        
        var news = News(
            title: title,
            description: newsDescription,
            scrappedDescription: scrappedDescription,
            category: category,
            imageUrl: imageUrl,
            link: link,
            pubDate: pubDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sourceMedium: sourceMedium,
            neutralScore: neutralScore,
            group: group,
            embedding: embeddingArray
        )
        news.id = id
        return news
    }
}