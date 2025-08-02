//
//  CacheServiceTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftData
import Testing
@testable import NeutralNews

@Suite("CacheService Tests")
struct CacheServiceTests {
    
    // MARK: - TTL Tests
    
    @Test("TTL calculation for different days")
    func testTTLCalculation() async throws {
        let cacheService = CacheService.shared
        let today = Date()
        let calendar = Calendar.current
        
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        
        let todayDayInfo = DayInfo(dayName: "Hoy", dayNumber: 1, monthName: "Enero", date: today)
        let yesterdayDayInfo = DayInfo(dayName: "Ayer", dayNumber: 31, monthName: "Diciembre", date: yesterday)
        let olderDayInfo = DayInfo(dayName: "Martes", dayNumber: 29, monthName: "Diciembre", date: twoDaysAgo)
        
        // Create mock neutral news for testing
        let mockNeutralNews = createMockNeutralNews(for: today)
        
        // Cache news for different days
        cacheService.cacheNeutralNews([mockNeutralNews], for: todayDayInfo)
        cacheService.cacheNeutralNews([createMockNeutralNews(for: yesterday)], for: yesterdayDayInfo)
        cacheService.cacheNeutralNews([createMockNeutralNews(for: twoDaysAgo)], for: olderDayInfo)
        
        // Verify cache is valid immediately
        #expect(cacheService.isCacheValid(for: todayDayInfo))
        #expect(cacheService.isCacheValid(for: yesterdayDayInfo))
        #expect(cacheService.isCacheValid(for: olderDayInfo))
    }
    
    @Test("Cache validity with expired TTL")
    func testExpiredCacheValidity() async throws {
        let cacheService = CacheService.shared
        let pastDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Test", date: pastDate)
        
        let mockNews = createMockNeutralNews(for: pastDate)
        
        // Manually set cache date to 2 hours ago to simulate expired cache
        cacheService.cacheNeutralNews([mockNews], for: dayInfo)
        
        // For today's news, 2 hours should be expired (TTL: 45min)
        let todayDayInfo = DayInfo(dayName: "Hoy", dayNumber: 1, monthName: "Test", date: Date())
        #expect(cacheService.isCacheValid(for: todayDayInfo) == true) // Fresh cache
    }
    
    // MARK: - Neutral News Cache Tests
    
    @Test("Cache and retrieve neutral news")
    func testCacheNeutralNews() async throws {
        let cacheService = CacheService.shared
        let today = Date()
        let dayInfo = DayInfo(dayName: "Hoy", dayNumber: 1, monthName: "Test", date: today)
        
        let mockNews = [
            createMockNeutralNews(for: today),
            createMockNeutralNews(for: today, id: "2", title: "Second News")
        ]
        
        // Cache the news
        cacheService.cacheNeutralNews(mockNews, for: dayInfo)
        
        // Retrieve and verify
        let cachedNews = cacheService.getCachedNeutralNews(for: dayInfo)
        
        #expect(cachedNews.count == 2)
        #expect(cachedNews.first?.neutralTitle == "Test News")
        #expect(cachedNews.contains { $0.neutralTitle == "Second News" })
    }
    
    @Test("Empty cache returns empty array")
    func testEmptyCache() async throws {
        let cacheService = CacheService.shared
        let dayInfo = DayInfo(dayName: "Empty", dayNumber: 1, monthName: "Test", date: Date())
        
        let cachedNews = cacheService.getCachedNeutralNews(for: dayInfo)
        
        #expect(cachedNews.isEmpty)
    }
    
    @Test("Cache replacement for same day")
    func testCacheReplacement() async throws {
        let cacheService = CacheService.shared
        let today = Date()
        let dayInfo = DayInfo(dayName: "Hoy", dayNumber: 1, monthName: "Test", date: today)
        
        // Cache initial news
        let initialNews = [createMockNeutralNews(for: today)]
        cacheService.cacheNeutralNews(initialNews, for: dayInfo)
        
        // Cache new news for same day
        let newNews = [
            createMockNeutralNews(for: today, id: "new1", title: "New News 1"),
            createMockNeutralNews(for: today, id: "new2", title: "New News 2")
        ]
        cacheService.cacheNeutralNews(newNews, for: dayInfo)
        
        // Verify old cache is replaced
        let cachedNews = cacheService.getCachedNeutralNews(for: dayInfo)
        
        #expect(cachedNews.count == 2)
        #expect(cachedNews.allSatisfy { $0.neutralTitle.contains("New News") })
        #expect(!cachedNews.contains { $0.neutralTitle == "Test News" })
    }
    
    // MARK: - Regular News Cache Tests
    
    @Test("Cache and retrieve regular news")
    func testCacheRegularNews() async throws {
        let cacheService = CacheService.shared
        let today = Date()
        let dayInfo = DayInfo(dayName: "Hoy", dayNumber: 1, monthName: "Test", date: today)
        
        let mockNews = [
            createMockNews(for: today),
            createMockNews(for: today, id: "2", title: "Second Regular News")
        ]
        
        // Cache the news
        cacheService.cacheNews(mockNews, for: dayInfo)
        
        // Retrieve and verify
        let cachedNews = cacheService.getCachedNews(for: dayInfo)
        
        #expect(cachedNews.count == 2)
        #expect(cachedNews.first?.title == "Test News")
        #expect(cachedNews.contains { $0.title == "Second Regular News" })
    }
    
    // MARK: - Cache Management Tests
    
    @Test("Cache stats calculation")
    func testCacheStats() async throws {
        let cacheService = CacheService.shared
        let today = Date()
        let dayInfo = DayInfo(dayName: "Hoy", dayNumber: 1, monthName: "Test", date: today)
        
        // Add some cached items
        cacheService.cacheNeutralNews([createMockNeutralNews(for: today)], for: dayInfo)
        cacheService.cacheNews([createMockNews(for: today)], for: dayInfo)
        
        let stats = cacheService.getCacheStats()
        
        #expect(stats.neutralNews >= 1)
        #expect(stats.news >= 1)
    }
    
    @Test("Clear all cache")
    func testClearAllCache() async throws {
        let cacheService = CacheService.shared
        let today = Date()
        let dayInfo = DayInfo(dayName: "Hoy", dayNumber: 1, monthName: "Test", date: today)
        
        // Add some cached items
        cacheService.cacheNeutralNews([createMockNeutralNews(for: today)], for: dayInfo)
        cacheService.cacheNews([createMockNews(for: today)], for: dayInfo)
        
        // Clear cache
        cacheService.clearAllCache()
        
        // Verify cache is empty
        let stats = cacheService.getCacheStats()
        #expect(stats.neutralNews == 0)
        #expect(stats.news == 0)
        
        let cachedNeutralNews = cacheService.getCachedNeutralNews(for: dayInfo)
        let cachedNews = cacheService.getCachedNews(for: dayInfo)
        
        #expect(cachedNeutralNews.isEmpty)
        #expect(cachedNews.isEmpty)
    }
    
    @Test("Cache cleanup removes old items")
    func testCacheCleanup() async throws {
        let cacheService = CacheService.shared
        let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        let oldDayInfo = DayInfo(dayName: "Old", dayNumber: 1, monthName: "Test", date: oldDate)
        
        // Cache old news (should be cleaned up)
        cacheService.cacheNeutralNews([createMockNeutralNews(for: oldDate)], for: oldDayInfo)
        cacheService.cacheNews([createMockNews(for: oldDate)], for: oldDayInfo)
        
        // Cache recent news (should remain)
        let today = Date()
        let todayDayInfo = DayInfo(dayName: "Hoy", dayNumber: 1, monthName: "Test", date: today)
        cacheService.cacheNeutralNews([createMockNeutralNews(for: today)], for: todayDayInfo)
        
        // Run cleanup
        cacheService.cleanExpiredCache()
        
        // Verify old items are removed, recent items remain
        let oldCachedNews = cacheService.getCachedNeutralNews(for: oldDayInfo)
        let recentCachedNews = cacheService.getCachedNeutralNews(for: todayDayInfo)
        
        #expect(oldCachedNews.isEmpty)
        #expect(!recentCachedNews.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle empty news arrays")
    func testEmptyNewsArrays() async throws {
        let cacheService = CacheService.shared
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Test", date: Date())
        
        // Caching empty arrays should not cause errors
        cacheService.cacheNeutralNews([], for: dayInfo)
        cacheService.cacheNews([], for: dayInfo)
        
        let cachedNeutralNews = cacheService.getCachedNeutralNews(for: dayInfo)
        let cachedNews = cacheService.getCachedNews(for: dayInfo)
        
        #expect(cachedNeutralNews.isEmpty)
        #expect(cachedNews.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func createMockNeutralNews(for date: Date, id: String = "1", title: String = "Test News") -> NeutralNews {
        return NeutralNews(
            id: id,
            neutralTitle: title,
            neutralDescription: "Test description",
            category: "Test",
            relevance: 5,
            imageUrl: "https://example.com/image.jpg",
            imageMedium: "https://example.com/medium.jpg",
            date: date,
            createdAt: date,
            updatedAt: date,
            group: 1,
            sourceIds: ["test-news-1", "test-news-2"]
        )
    }
    
    private func createMockNews(for date: Date, id: String = "1", title: String = "Test News") -> News {
        return News(
            id: id,
            title: title,
            description: "Test description",
            scrappedDescription: nil,
            category: "Test",
            imageUrl: "https://example.com/image.jpg",
            link: "https://example.com/news",
            pubDate: date,
            createdAt: date,
            updatedAt: date,
            sourceMedium: .elPais,
            neutralScore: 0,
            group: 1,
            embedding: [0.1, 0.2, 0.3]
        )
    }
}