//
//  FirestoreService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private let regionProvider: ContentRegionProviding
    
    private enum Collection {
        #if DEBUG
        static let reports = "reports_dev"
        #else
        static let reports = "reports"
        #endif
        
        static func neutralNews(for region: ContentRegion) -> String {
            switch region {
            case .us:
                return "neutral_news_us"
            case .es:
                return "neutral_news"
            }
        }
        
        static func news(for region: ContentRegion) -> String {
            switch region {
            case .us:
                return "news_us"
            case .es:
                return "news"
            }
        }
    }
    
    private init(regionProvider: ContentRegionProviding = ContentRegionProvider()) {
        self.regionProvider = regionProvider
    }
    
    // MARK: - Neutral News Methods
    
    func fetchNeutralNews(for day: DayInfo) async throws -> [NeutralNews] {
        let start = Calendar.current.startOfDay(for: day.date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let region = regionProvider.currentRegion
        
        let snapshot = try await db.collection(Collection.neutralNews(for: region))
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("date", isLessThan: Timestamp(date: end))
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> NeutralNews? in
            parseNeutralNews(from: doc.data(), documentID: doc.documentID)
        }
    }

    func fetchNeutralNews(newsId: String) async throws -> NeutralNews? {
        let region = regionProvider.currentRegion
        let document = try await db.collection(Collection.neutralNews(for: region))
            .document(newsId)
            .getDocument()

        guard let data = document.data() else {
            return nil
        }

        return parseNeutralNews(from: data, documentID: document.documentID)
    }
    
    
    // MARK: - Reports Methods
    
    func submitReport(for news: NeutralNews, problemType: Problem) async throws {
        let reportData: [String: Any] = [
            "news_id": news.id,
            "news_title": news.neutralTitle,
            "group": news.group,
            "problem_type": problemType.title,
            "date": Timestamp(date: Date.now)
        ]
        
#if DEBUG
        print("📤 Submitting report data: \(reportData)")
#endif
        let docRef = try await db.collection(Collection.reports).addDocument(data: reportData)
#if DEBUG
        print("📄 Report created with ID: \(docRef.documentID)")
#endif
    }
    
    // MARK: - News Methods
    
    func fetchNews(for day: DayInfo) async throws -> [News] {
        let start = Calendar.current.startOfDay(for: day.date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let region = regionProvider.currentRegion
        
        let snapshot = try await db.collection(Collection.news(for: region))
            .whereField("pub_date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("pub_date", isLessThan: Timestamp(date: end))
            .whereField("group", isGreaterThan: -1)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> News? in
            parseNews(from: doc.data(), documentID: doc.documentID)
        }
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseNeutralNews(from data: [String: Any], documentID: String) -> NeutralNews? {
        guard let neutralTitle = data["neutral_title"] as? String,
              let neutralDescription = data["neutral_description"] as? String,
              let category = (data["category_id"] as? String) ?? (data["category"] as? String),
              let relevance = data["relevance"] as? Int,
              let imageUrl = data["image_url"] as? String,
              let imageMedium = data["image_medium"] as? String,
              let date = data["date"] as? Timestamp,
              let createdAt = data["created_at"] as? Timestamp,
              let updatedAt = data["updated_at"] as? Timestamp,
              let group = data["group"] as? Int,
              let sourceIds = data["source_ids"] as? [String]
        else { return nil }
        
        return NeutralNews(
            id: documentID,
            neutralTitle: neutralTitle,
            neutralDescription: neutralDescription,
            category: category,
            relevance: relevance,
            imageUrl: imageUrl,
            imageMedium: imageMedium,
            date: date.dateValue(),
            createdAt: createdAt.dateValue(),
            updatedAt: updatedAt.dateValue(),
            group: group,
            sourceIds: sourceIds
        )
    }
    
    private func parseNews(from data: [String: Any], documentID: String) -> News? {
        guard let title = data["title"] as? String,
              let description = data["description_short"] as? String,
              let group = data["group"] as? Int,
              let category = (data["category_id"] as? String) ?? (data["category"] as? String),
              let link = data["link"] as? String,
              let pubDate = data["pub_date"] as? Timestamp,
              let createdAt = data["created_at"] as? Timestamp,
              let updatedAt = data["updated_at"] as? Timestamp,
              let neutralScore = data["neutral_score"] as? Int,
              let publisher = data["publisher"] as? String
        else { return nil }

        let scrappedDescription = data["scrapped_description"] as? String
        let imageUrl = data["image_url"] as? String
        let embedding = data["embedding"] as? [Double] ?? []

        return News(
            id: documentID,
            title: title,
            description: description,
            scrappedDescription: scrappedDescription,
            category: category,
            imageUrl: imageUrl,
            link: link,
            pubDate: pubDate.dateValue(),
            createdAt: createdAt.dateValue(),
            updatedAt: updatedAt.dateValue(),
            publisher: publisher,
            neutralScore: neutralScore,
            group: group,
            embedding: embedding
        )
    }
}
