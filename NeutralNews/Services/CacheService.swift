//
//  CacheService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftData

final class CacheService {
    static let shared = CacheService()

    private var modelContainer: ModelContainer
    private static let lastCleanupKey = "CacheService.lastCleanupDate"

    // TTL Configuration (more aggressive for better performance)
    private enum TTL {
        static let today: TimeInterval = 45 * 60          // 45 minutes
        static let yesterday: TimeInterval = 4 * 60 * 60  // 4 hours
        static let older: TimeInterval = 24 * 60 * 60     // 24 hours
    }

    // Cleanup interval: 6 hours between cleanups
    private static let cleanupInterval: TimeInterval = 6 * 60 * 60

    private init() {
        do {
            let configuration = ModelConfiguration(
                schema: Schema([CachedNeutralNews.self, CachedNews.self]),
                url: URL.documentsDirectory.appending(path: "LocalCache.store"),
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(for: Schema([CachedNeutralNews.self, CachedNews.self]), configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    private func createContext() -> ModelContext {
        return ModelContext(modelContainer)
    }
    
    // MARK: - Auto-Cleanup

    /// Last cleanup date persisted in UserDefaults (survives app restarts)
    private var lastCleanupDate: Date? {
        get {
            UserDefaults.standard.object(forKey: Self.lastCleanupKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.lastCleanupKey)
        }
    }

    /// Performs cache cleanup if needed based on time interval (6 hours).
    ///
    /// Checks time since last cleanup across app sessions using UserDefaults persistence.
    /// If enough time has passed, triggers background cleanup of expired cache items.
    ///
    /// - Note: Cleanup runs in background with `.utility` priority to avoid blocking UI
    /// - Important: Cleanup interval is 6 hours. Skips if last cleanup was within this window.
    func cleanExpiredCacheIfNeeded() {
        let now = Date()

        // Check if enough time has passed since last cleanup
        if let lastClean = lastCleanupDate {
            let timeSinceLastCleanup = now.timeIntervalSince(lastClean)
            if timeSinceLastCleanup < Self.cleanupInterval {
                return
            }
        }

#if DEBUG
        print("🧹 Starting cache cleanup...")
#endif

        // Perform cleanup in background to avoid blocking UI
        Task.detached(priority: .utility) { [weak self] in
            await self?.cleanExpiredCache()

            await MainActor.run { [weak self] in
                self?.lastCleanupDate = now
#if DEBUG
                print("✅ Cache cleanup completed")
#endif
            }
        }
    }
    
    // MARK: - Cache Check Methods

    /// Checks if cached data for a specific day is still valid based on TTL (Time To Live).
    ///
    /// TTL varies by day:
    /// - Today: 45 minutes
    /// - Yesterday: 4 hours
    /// - Older: 24 hours
    ///
    /// - Parameter day: The day to check cache validity for
    /// - Returns: `true` if valid cached data exists, `false` otherwise
    /// - Note: Triggers cache cleanup check as a side effect
    func isCacheValid(for day: DayInfo) -> Bool {
        cleanExpiredCacheIfNeeded()
        let context = createContext()
        let startOfDay = Calendar.current.startOfDay(for: day.date)
        let ttl = getTTL(for: day.date)
        let cutoffDate = Date().addingTimeInterval(-ttl)
        
        let descriptor = FetchDescriptor<CachedNeutralNews>(
            predicate: #Predicate<CachedNeutralNews> { cached in
                cached.dayDate == startOfDay && cached.cacheDate > cutoffDate
            }
        )
        
        do {
            let count = try context.fetchCount(descriptor)
            return count > 0
        } catch {
            print("Error checking cache validity: \(error)")
            return false
        }
    }
    
    // MARK: - Neutral News Cache Methods

    /// Retrieves cached neutral news for a specific day if within TTL window.
    ///
    /// - Parameter day: The day to retrieve cached news for
    /// - Returns: Array of `NeutralNews` items sorted by date (newest first). Returns empty array if cache miss or expired.
    /// - Note: Triggers cache cleanup check as a side effect
    func getCachedNeutralNews(for day: DayInfo) -> [NeutralNews] {
        cleanExpiredCacheIfNeeded()
        let context = createContext()
        let startOfDay = Calendar.current.startOfDay(for: day.date)
        let ttl = getTTL(for: day.date)
        let cutoffDate = Date().addingTimeInterval(-ttl)
        
        let descriptor = FetchDescriptor<CachedNeutralNews>(
            predicate: #Predicate<CachedNeutralNews> { cached in
                cached.dayDate == startOfDay && cached.cacheDate > cutoffDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let cachedItems = try context.fetch(descriptor)
            return cachedItems.map { $0.toNeutralNews() }
        } catch {
            print("Error fetching cached neutral news: \(error)")
            return []
        }
    }
    
    /// Stores neutral news in SwiftData cache for a specific day.
    ///
    /// Replaces any existing cache for the day with fresh data.
    ///
    /// - Parameters:
    ///   - news: Array of `NeutralNews` items to cache
    ///   - day: The day these news items belong to
    /// - Note: Does nothing if news array is empty
    func cacheNeutralNews(_ news: [NeutralNews], for day: DayInfo) {
        guard !news.isEmpty else { return }
        
        let context = createContext()
        let startOfDay = Calendar.current.startOfDay(for: day.date)
        
        // First, remove any existing cache for this day
        removeCachedNeutralNews(for: day, context: context)
        
        // Add new cache entries
        for item in news {
            let cachedItem = CachedNeutralNews(from: item)
            cachedItem.dayDate = startOfDay // Ensure it's set to the day we're caching for
            context.insert(cachedItem)
        }
        
        saveContext(context)
    }
    
    private func removeCachedNeutralNews(for day: DayInfo, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: day.date)
        
        let descriptor = FetchDescriptor<CachedNeutralNews>(
            predicate: #Predicate<CachedNeutralNews> { cached in
                cached.dayDate == startOfDay
            }
        )
        
        do {
            let cachedItems = try context.fetch(descriptor)
            for item in cachedItems {
                context.delete(item)
            }
        } catch {
            print("Error removing cached neutral news: \(error)")
        }
    }
    
    // MARK: - Regular News Cache Methods

    /// Retrieves cached regular news (from media sources) for a specific day if within TTL window.
    ///
    /// - Parameter day: The day to retrieve cached news for
    /// - Returns: Array of `News` items sorted by publication date (newest first). Returns empty array if cache miss or expired.
    /// - Note: Triggers cache cleanup check as a side effect
    func getCachedNews(for day: DayInfo) -> [News] {
        cleanExpiredCacheIfNeeded()
        let context = createContext()
        let startOfDay = Calendar.current.startOfDay(for: day.date)
        let ttl = getTTL(for: day.date)
        let cutoffDate = Date().addingTimeInterval(-ttl)
        
        let descriptor = FetchDescriptor<CachedNews>(
            predicate: #Predicate<CachedNews> { cached in
                cached.dayDate == startOfDay && cached.cacheDate > cutoffDate
            },
            sortBy: [SortDescriptor(\.pubDate, order: .reverse)]
        )
        
        do {
            let cachedItems = try context.fetch(descriptor)
            return cachedItems.compactMap { $0.toNews() }
        } catch {
            print("Error fetching cached news: \(error)")
            return []
        }
    }
    
    /// Stores regular news in SwiftData cache for a specific day.
    ///
    /// Replaces any existing cache for the day with fresh data.
    ///
    /// - Parameters:
    ///   - news: Array of `News` items to cache
    ///   - day: The day these news items belong to
    /// - Note: Does nothing if news array is empty
    func cacheNews(_ news: [News], for day: DayInfo) {
        guard !news.isEmpty else { return }
        
        let context = createContext()
        let startOfDay = Calendar.current.startOfDay(for: day.date)
        
        // Remove existing cache for this day
        removeCachedNews(for: day, context: context)
        
        // Add new cache entries
        for item in news {
            let cachedItem = CachedNews(from: item)
            cachedItem.dayDate = startOfDay
            context.insert(cachedItem)
        }
        
        saveContext(context)
    }
    
    private func removeCachedNews(for day: DayInfo, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: day.date)
        
        let descriptor = FetchDescriptor<CachedNews>(
            predicate: #Predicate<CachedNews> { cached in
                cached.dayDate == startOfDay
            }
        )
        
        do {
            let cachedItems = try context.fetch(descriptor)
            for item in cachedItems {
                context.delete(item)
            }
        } catch {
            print("Error removing cached news: \(error)")
        }
    }
    
    // MARK: - Cache Management

    /// Performs comprehensive cache cleanup in the background.
    ///
    /// This method executes three cleanup operations:
    /// 1. Removes neutral news older than 7 days
    /// 2. Removes regular news older than 7 days
    /// 3. Removes TTL-expired items for the last 7 days
    ///
    /// - Note: This is an async operation that should be called from background tasks
    func cleanExpiredCache() async {
        await cleanExpiredNeutralNews()
        await cleanExpiredNews()
        await cleanOldCache()
    }
    
    private func cleanExpiredNeutralNews() async {
        let context = createContext()
        // Clean cache older than 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        let descriptor = FetchDescriptor<CachedNeutralNews>(
            predicate: #Predicate<CachedNeutralNews> { cached in
                cached.dayDate < sevenDaysAgo
            }
        )

        do {
            let expiredItems = try context.fetch(descriptor)
            for item in expiredItems {
                context.delete(item)
            }
#if DEBUG
            print("🗑️ Cleaned \(expiredItems.count) expired neutral news items")
#endif
            saveContext(context)
        } catch {
            print("❌ Error cleaning expired neutral news: \(error)")
        }
    }

    private func cleanExpiredNews() async {
        let context = createContext()
        // Clean cache older than 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        let descriptor = FetchDescriptor<CachedNews>(
            predicate: #Predicate<CachedNews> { cached in
                cached.dayDate < sevenDaysAgo
            }
        )

        do {
            let expiredItems = try context.fetch(descriptor)
            for item in expiredItems {
                context.delete(item)
            }
#if DEBUG
            print("🗑️ Cleaned \(expiredItems.count) expired news items")
#endif
            saveContext(context)
        } catch {
            print("❌ Error cleaning expired news: \(error)")
        }
    }

    private func cleanOldCache() async {
        let context = createContext()
        // Also clean based on TTL for current days
        let calendar = Calendar.current
        let today = Date()

        var totalCleaned = 0

        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStartDate = calendar.startOfDay(for: dayDate)
            let ttl = getTTL(for: dayDate)
            let cutoffDate = today.addingTimeInterval(-ttl)

            // Clean expired neutral news for this day
            let neutralDescriptor = FetchDescriptor<CachedNeutralNews>(
                predicate: #Predicate<CachedNeutralNews> { cached in
                    cached.dayDate == dayStartDate && cached.cacheDate < cutoffDate
                }
            )

            do {
                let expiredNeutral = try context.fetch(neutralDescriptor)
                for item in expiredNeutral {
                    context.delete(item)
                }
                totalCleaned += expiredNeutral.count
            } catch {
                print("❌ Error cleaning expired neutral news for day \(dayOffset): \(error)")
            }

            // Clean expired regular news for this day
            let newsDescriptor = FetchDescriptor<CachedNews>(
                predicate: #Predicate<CachedNews> { cached in
                    cached.dayDate == dayStartDate && cached.cacheDate < cutoffDate
                }
            )

            do {
                let expiredNews = try context.fetch(newsDescriptor)
                for item in expiredNews {
                    context.delete(item)
                }
                totalCleaned += expiredNews.count
            } catch {
                print("❌ Error cleaning expired news for day \(dayOffset): \(error)")
            }
        }

#if DEBUG
        if totalCleaned > 0 {
            print("🗑️ Cleaned \(totalCleaned) TTL-expired cache items")
        }
#endif

        saveContext(context)
    }
    
    // MARK: - Helper Methods
    
    private func getTTL(for date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: date)
        
        let daysDifference = calendar.dateComponents([.day], from: targetDay, to: today).day ?? 0
        
        switch daysDifference {
        case 0: return TTL.today      // Today: 45 minutes
        case 1: return TTL.yesterday  // Yesterday: 4 hours
        default: return TTL.older     // Older: 24 hours
        }
    }
    
    private func saveContext(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("Error saving cache context: \(error)")
        }
    }
    
    // MARK: - Debug Methods

    /// Retrieves cache statistics for monitoring and debugging.
    ///
    /// - Returns: A tuple containing counts of cached items:
    ///   - `neutralNews`: Number of cached neutral news items in SwiftData
    ///   - `news`: Number of cached regular news items in SwiftData
    func getCacheStats() -> (neutralNews: Int, news: Int) {
        let context = createContext()
        do {
            let neutralCount = try context.fetchCount(FetchDescriptor<CachedNeutralNews>())
            let newsCount = try context.fetchCount(FetchDescriptor<CachedNews>())
            return (neutralNews: neutralCount, news: newsCount)
        } catch {
            print("Error getting cache stats: \(error)")
            return (neutralNews: 0, news: 0)
        }
    }
    
    /// Clears all cached data from SwiftData storage.
    ///
    /// Use this for debugging or when implementing a "clear cache" feature.
    ///
    /// - Warning: This permanently deletes all cached news data. Use with caution.
    /// - Note: This is an async operation
    func clearAllCache() async {
        let context = createContext()
        do {
            try context.delete(model: CachedNeutralNews.self)
            try context.delete(model: CachedNews.self)
            saveContext(context)
#if DEBUG
            print("🗑️ All cache cleared")
#endif
        } catch {
            print("❌ Error clearing all cache: \(error)")
        }
    }
}
