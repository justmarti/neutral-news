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

    /// Performs cache cleanup if needed (checks time since last cleanup across app sessions)
    func cleanExpiredCacheIfNeeded() {
        let now = Date()

        // Check if enough time has passed since last cleanup
        if let lastClean = lastCleanupDate {
            let timeSinceLastCleanup = now.timeIntervalSince(lastClean)
            if timeSinceLastCleanup < Self.cleanupInterval {
#if DEBUG
                let hoursRemaining = (Self.cleanupInterval - timeSinceLastCleanup) / 3600
                print("⏳ Skipping cleanup - \(String(format: "%.1f", hoursRemaining)) hours until next cleanup")
#endif
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
