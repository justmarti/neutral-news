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

    private init() {}

    func saveNews(_ news: Any, context: NSManagedObjectContext) throws {
        print("🔄 SavedNewsService.saveNews called")

        let newsId: String

        if let neutralNews = news as? NeutralNews {
            print("📰 Preparing to save NeutralNews: \(neutralNews.id)")
            newsId = neutralNews.id
        } else if let regularNews = news as? News {
            print("📰 Preparing to save News: \(regularNews.id)")
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
            print("⚠️ News already saved: \(newsId)")
            return // Already saved, no need to save again
        }

        print("✅ News not found in saved list, proceeding to save: \(newsId)")

        // Create the object ONLY if not already saved
        if let neutralNews = news as? NeutralNews {
            _ = SavedNews(from: neutralNews, context: context)
            print("📰 Created SavedNews from NeutralNews: \(neutralNews.id)")
        } else if let regularNews = news as? News {
            _ = SavedNews(from: regularNews, context: context)
            print("📰 Created SavedNews from News: \(regularNews.id)")
        } else {
            throw SavedNewsError.invalidNewsType
        }

        print("💾 Saving context...")
        try context.save()
        print("✅ Context saved successfully")

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
        }
    }

    func isNewsSaved(newsId: String, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<SavedNews> = SavedNews.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "newsId == %@", newsId)

        let results = try? context.fetch(fetchRequest)
        let isSaved = results?.first != nil
        print("🔍 Checking if news \(newsId) is saved: \(isSaved) (found \(results?.count ?? 0) results)")
        return isSaved
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
