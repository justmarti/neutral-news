//
//  SavedNewsService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/20/25.
//

import Foundation
import CoreData

// MARK: - Service
final class SavedNewsService {
    static let shared = SavedNewsService()
    private let newsDataManager = NewsDataManager.shared

    private init() {}

    func saveNews(_ news: Any, context: NSManagedObjectContext) throws {
#if DEBUG
        print("🔄 SavedNewsService.saveNews called")
#endif

        let newsId: String

        if let neutralNews = news as? NeutralNews {
#if DEBUG
            print("📰 Preparing to save NeutralNews: \(neutralNews.id)")
#endif
            newsId = neutralNews.id
        } else if let regularNews = news as? News {
#if DEBUG
            print("📰 Preparing to save News: \(regularNews.id)")
#endif
            newsId = regularNews.id
        } else {
            print("❌ Invalid news type: \(type(of: news))")
            throw SavedNewsError.invalidNewsType
        }

        // Check if already saved FIRST
        let fetchRequest: NSFetchRequest<SavedNews> = SavedNews.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "newsId == %@", newsId)

        let existingResults = try context.fetch(fetchRequest)
        if !existingResults.isEmpty {
#if DEBUG
            print("⚠️ News already saved: \(newsId)")
#endif
            return // Already saved, no need to save again
        }

#if DEBUG
        print("✅ News not found in saved list, proceeding to save: \(newsId)")
#endif

        // Create the object ONLY if not already saved
        if let neutralNews = news as? NeutralNews {
            let relatedNews = newsDataManager.getRelatedNews(from: neutralNews)
            _ = SavedNews(from: neutralNews, relatedNews: relatedNews, context: context)
#if DEBUG
            print("📰 Created SavedNews from NeutralNews: \(neutralNews.id)")
#endif
        } else if let regularNews = news as? News {
            _ = SavedNews(from: regularNews, context: context)
#if DEBUG
            print("📰 Created SavedNews from News: \(regularNews.id)")
#endif
        } else {
            throw SavedNewsError.invalidNewsType
        }

#if DEBUG
        print("💾 Saving context...")
#endif
        try context.save()
#if DEBUG
        print("✅ Context saved successfully")
#endif
        Task { @MainActor in
            SavedNewsState.shared.setSaved(true, for: newsId)
        }

        // Track positive interaction for rating
        Task { @MainActor in
            RatingManager.shared.incrementSavedNewsCount()
            RatingManager.shared.requestRatingAfterPositiveInteraction()
        }
    }

    func unsaveNews(newsId: String, context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<SavedNews> = SavedNews.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "newsId == %@", newsId)

        if let savedNews = try context.fetch(fetchRequest).first {
            context.delete(savedNews)
            try context.save()
            Task { @MainActor in
                SavedNewsState.shared.setSaved(false, for: newsId)
            }
        }
    }

    func isNewsSaved(newsId: String, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<SavedNews> = SavedNews.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "newsId == %@", newsId)

        let results = try? context.fetch(fetchRequest)
        return results?.first != nil
    }

    func getSavedNews(context: NSManagedObjectContext) throws -> [SavedNews] {
        let fetchRequest: NSFetchRequest<SavedNews> = SavedNews.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        return try context.fetch(fetchRequest)
    }
}

enum SavedNewsError: Error {
    case invalidNewsType
    case saveFailure
    case fetchFailure
}
