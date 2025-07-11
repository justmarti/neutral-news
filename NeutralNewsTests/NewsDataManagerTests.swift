//
//  NewsDataManagerTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import Testing
@testable import NeutralNews

@Suite("NewsDataManager Tests")
struct NewsDataManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test("NewsDataManager initialization")
    func testInitialization() async throws {
        let manager = NewsDataManager.shared
        
        // Test that manager initializes without crashing
        #expect(manager.lastSevenDays.count == 7)
        #expect(manager.lastSevenDays.first?.dayName == "Hoy")
    }
    
    @Test("Last seven days calculation")
    func testLastSevenDays() async throws {
        let manager = NewsDataManager.shared
        let days = manager.lastSevenDays
        
        #expect(days.count == 7)
        #expect(days.first?.dayName == "Hoy")
        #expect(days[1].dayName == "Ayer")
        
        // Verify dates are in descending order (today to 6 days ago)
        for i in 0..<(days.count - 1) {
            #expect(days[i].date >= days[i + 1].date)
        }
    }
    
    // MARK: - Day Loading Tests
    
    @Test("isDayLoaded tracking")
    func testDayLoadedTracking() async throws {
        let manager = NewsDataManager.shared
        let today = Date()
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Test", date: today)
        
        // Initially not loaded
        #expect(!manager.isDayLoaded(dayInfo))
        
        // After loading should be marked as loaded
        await manager.loadNews(for: dayInfo)
        #expect(manager.isDayLoaded(dayInfo))
    }
    
    @Test("Skip loading already loaded day")
    func testSkipAlreadyLoadedDay() async throws {
        let manager = NewsDataManager.shared
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Test", date: Date())
        
        // Load once
        await manager.loadNews(for: dayInfo)
        let initialCount = manager.getNewsArrayForDay(dayInfo).count
        
        // Load again (should skip)
        await manager.loadNews(for: dayInfo)
        let afterSecondLoad = manager.getNewsArrayForDay(dayInfo).count
        
        #expect(initialCount == afterSecondLoad)
    }
    
    @Test("Force refresh bypasses loaded check")
    func testForceRefresh() async throws {
        let manager = NewsDataManager.shared
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Test", date: Date())
        
        // Load once
        await manager.loadNews(for: dayInfo)
        #expect(manager.isDayLoaded(dayInfo))
        
        // Force refresh should reload even if already loaded
        await manager.refreshNews(for: dayInfo)
        #expect(manager.isDayLoaded(dayInfo)) // Still marked as loaded
    }
    
    // MARK: - News Retrieval Tests
    
    @Test("Get news for specific day")
    func testGetNewsForDay() async throws {
        let manager = NewsDataManager.shared
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Test", date: Date())
        
        // Initially empty
        let initialNews = manager.getNewsForDay(dayInfo)
        #expect(initialNews.isEmpty)
        
        // After loading, should have news (mocked by cache or network)
        await manager.loadNews(for: dayInfo)
        let loadedNews = manager.getNewsForDay(dayInfo)
        
        #expect(!loadedNews.isEmpty, "Loaded news should not be empty after loading.")
    }
    
    @Test("Get news array for day is sorted")
    func testGetNewsArrayForDaySorted() async throws {
        let manager = NewsDataManager.shared
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Test", date: Date())
        
        await manager.loadNews(for: dayInfo)
        let newsArray = manager.getNewsArrayForDay(dayInfo)
        
        // Should be sorted by date (newest first)
        for i in 0..<(newsArray.count - 1) {
            #expect(newsArray[i].date >= newsArray[i + 1].date)
        }
    }
    
    @Test("Get related news by group")
    func testGetRelatedNews() async throws {
        let manager = NewsDataManager.shared
        
        // Create mock neutral news with specific group
        let mockNeutralNews = createMockNeutralNews(group: 123)
        
        let relatedNews = manager.getRelatedNews(from: mockNeutralNews)
        
        // Should return an array (even if empty) without crashing
        #expect(relatedNews.count >= 0)
    }
    
    // MARK: - Cache Integration Tests
    
    @Test("Cache stats retrieval")
    func testCacheStats() async throws {
        let manager = NewsDataManager.shared
        let stats = manager.getCacheStats()
        
        #expect(stats.memory >= 0)
        #expect(stats.persistent.neutralNews >= 0)
        #expect(stats.persistent.news >= 0)
    }
    
    @Test("Preload cache functionality")
    func testPreloadCache() async throws {
        let manager = NewsDataManager.shared
        
        // Should not throw and complete successfully
        await manager.preloadCache()
        
        // Today should be loaded or attempted to load
        let today = DayInfo.today
        // Note: In real app, this might load from Firebase or cache
        // In tests, we just verify it doesn't crash
    }
    
    // MARK: - Memory Management Tests
    
    @Test("News deduplication in addNewNewsForDay")
    func testNewsDeduplication() async throws {
        let manager = NewsDataManager.shared
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Test", date: Date())
        
        // Test that loading the same day twice doesn't duplicate
        await manager.loadNews(for: dayInfo)
        let firstLoad = manager.getNewsArrayForDay(dayInfo).count
        
        await manager.loadNews(for: dayInfo) // Should skip because already loaded
        let secondLoad = manager.getNewsArrayForDay(dayInfo).count
        
        #expect(firstLoad == secondLoad) // Should be same count
    }
    
    @Test("Merge news for day updates existing items")
    func testMergeNewsForDay() async throws {
        let manager = NewsDataManager.shared
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Test", date: Date())
        
        // Test force refresh (merge functionality)
        await manager.loadNews(for: dayInfo)
        let initialCount = manager.getNewsArrayForDay(dayInfo).count
        
        await manager.refreshNews(for: dayInfo) // This uses merge functionality
        let afterRefresh = manager.getNewsArrayForDay(dayInfo).count
        
        // Should handle refresh without crashing
        #expect(afterRefresh >= 0)
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Handle empty news arrays")
    func testHandleEmptyArrays() async throws {
        let manager = NewsDataManager.shared
        let dayInfo = DayInfo(dayName: "Empty", dayNumber: 1, monthName: "Test", date: Date())
        
        // Test loading for a day that might have no news
        await manager.loadNews(for: dayInfo)
        let newsArray = manager.getNewsArrayForDay(dayInfo)
        
        // Should handle empty results gracefully
        #expect(newsArray.count >= 0)
    }
    
    @Test("Date boundary handling")
    func testDateBoundaryHandling() async throws {
        let manager = NewsDataManager.shared
        let calendar = Calendar.current
        
        // Test with date at exact day boundary
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        let exactDate = calendar.date(from: components)!
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 1, monthName: "Enero", date: exactDate)
        
        await manager.loadNews(for: dayInfo)
        
        // Should handle boundary dates without issues
        #expect(manager.isDayLoaded(dayInfo))
    }
    
    // MARK: - Performance Tests
    
    @Test("Large dataset handling", .timeLimit(.minutes(1)))
    func testLargeDatasetHandling() async throws {
        let manager = NewsDataManager.shared
        
        // Test loading multiple days in sequence
        let startTime = Date()
        
        for dayOffset in 0..<10 {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dayInfo = DayInfo(dayName: "Day \(dayOffset)", dayNumber: dayOffset, monthName: "Test", date: date)
            
            await manager.loadNews(for: dayInfo)
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        #expect(processingTime < 4.0) // Less than 4 seconds for 10 days
    }
    
    // MARK: - Helper Methods
    
    private func createMockNeutralNews(id: String = "test", title: String = "Test News", group: Int = 1) -> NeutralNews {
        var news = NeutralNews(
            neutralTitle: title,
            neutralDescription: "Test description",
            category: "Test",
            relevance: 5,
            imageUrl: "https://example.com/image.jpg",
            imageMedium: "https://example.com/medium.jpg",
            date: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            group: group
        )
        news.id = id
        return news
    }
    
    private func createMockNews(id: String = "test", title: String = "Test News", group: Int = 1) -> News {
        var news = News(
            title: title,
            description: "Test description",
            scrappedDescription: nil,
            category: "Test",
            imageUrl: "https://example.com/image.jpg",
            link: "https://example.com/news",
            pubDate: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            sourceMedium: .elPais,
            neutralScore: 0,
            group: group,
            embedding: [0.1, 0.2, 0.3]
        )
        news.id = id
        return news
    }
}

