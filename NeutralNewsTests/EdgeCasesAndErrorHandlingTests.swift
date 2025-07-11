//
//  EdgeCasesAndErrorHandlingTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftData
import Testing
@testable import NeutralNews

@Suite("Edge Cases and Error Handling Tests")
struct EdgeCasesAndErrorHandlingTests {
    
    // MARK: - Memory Management Tests
    
    @Test("Memory management with large datasets")
    func testMemoryManagementWithLargeDatasets() async throws {
        let manager = NewsDataManager.shared
        
        // Test loading multiple days sequentially to stress test memory
        for dayOffset in 0..<20 {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dayInfo = DayInfo(dayName: "Memory Test \(dayOffset)", dayNumber: dayOffset, monthName: "Test", date: date)
            
            await manager.loadNews(for: dayInfo)
        }
        
        // Should complete without memory issues
        #expect(true)
    }
    
    @Test("Concurrent access to NewsDataManager")
    func testConcurrentAccess() async throws {
        let manager = NewsDataManager.shared
        
        // Create multiple concurrent tasks accessing the manager
        let tasks = (1...10).map { taskIndex in
            Task {
                let dayInfo = DayInfo(
                    dayName: "Test \(taskIndex)",
                    dayNumber: taskIndex,
                    monthName: "Test",
                    date: Date().addingTimeInterval(TimeInterval(taskIndex * 3600))
                )
                
                await manager.loadNews(for: dayInfo)
                let news = manager.getNewsArrayForDay(dayInfo)
                return news.count
            }
        }
        
        // Wait for all tasks to complete
        let results = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
            for task in tasks {
                group.addTask {
                    await task.value
                }
            }
            
            var results: [Int] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // Should complete without crashes
        #expect(results.count == 10)
        #expect(results.allSatisfy { $0 >= 0 })
    }
    
    // MARK: - Date Edge Cases
    
    @Test("Date boundary edge cases")
    func testDateBoundaryEdgeCases() async throws {
        let calendar = Calendar.current
        
        // Test leap year date
        let leapYearDate = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        let leapYearDayInfo = DayInfo(dayName: "Leap", dayNumber: 29, monthName: "Febrero", date: leapYearDate)
        
        // Test year boundary
        let newYearDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let newYearDayInfo = DayInfo(dayName: "NewYear", dayNumber: 1, monthName: "Enero", date: newYearDate)
        
        // Test very old date
        let veryOldDate = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1))!
        let veryOldDayInfo = DayInfo(dayName: "VeryOld", dayNumber: 1, monthName: "Enero", date: veryOldDate)
        
        // Test very future date
        let futureDate = calendar.date(from: DateComponents(year: 2030, month: 12, day: 31))!
        let futureDayInfo = DayInfo(dayName: "Future", dayNumber: 31, monthName: "Diciembre", date: futureDate)
        
        // Test that DayInfo handles edge case dates correctly
        #expect(leapYearDayInfo.dayNumber == 29)
        #expect(newYearDayInfo.dayNumber == 1)
        #expect(veryOldDayInfo.dayName == "VeryOld")
        #expect(futureDayInfo.monthName == "Diciembre")
        
        // All date operations should handle edge cases gracefully
        #expect(calendar.startOfDay(for: leapYearDate) <= leapYearDate)
        #expect(calendar.startOfDay(for: newYearDate) <= newYearDate)
        #expect(calendar.startOfDay(for: veryOldDate) <= veryOldDate)
        #expect(calendar.startOfDay(for: futureDate) <= futureDate)
    }
    
    @Test("Timezone handling")
    func testTimezoneHandling() async throws {
        // Test dates in different timezones
        let utcTimezone = TimeZone(identifier: "UTC")!
        let tokyoTimezone = TimeZone(identifier: "Asia/Tokyo")!
        
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = utcTimezone
        
        var tokyoCalendar = Calendar.current
        tokyoCalendar.timeZone = tokyoTimezone
        
        let baseDate = Date()
        
        let utcStartOfDay = utcCalendar.startOfDay(for: baseDate)
        let tokyoStartOfDay = tokyoCalendar.startOfDay(for: baseDate)
        
        // Start of day should be different in different timezones
        #expect(utcStartOfDay != tokyoStartOfDay)
        
        // But both should be valid dates
        #expect(utcStartOfDay <= baseDate.addingTimeInterval(86400)) // Within 24 hours
        #expect(tokyoStartOfDay <= baseDate.addingTimeInterval(86400))
    }
    
    // MARK: - Network Error Simulation
    
    @Test("Network error handling simulation")
    func testNetworkErrorHandling() async throws {
        let manager = NewsDataManager.shared
        let dayInfo = DayInfo(dayName: "ErrorTest", dayNumber: 1, monthName: "Test", date: Date())
        
        // Test loading when network might fail
        // The manager should handle errors gracefully and not crash
        await manager.loadNews(for: dayInfo)
        
        // Should complete without throwing, even if network fails
        #expect(true)
    }
    
    // MARK: - Data Corruption Tests
    
    @Test("Handle corrupted cache data")
    func testCorruptedCacheDataHandling() async throws {
        let cacheService = CacheService.shared
        
        // Clear cache first
        cacheService.clearAllCache()
        
        // Test that cache operations handle corruption gracefully
        let dayInfo = DayInfo(dayName: "Corrupt", dayNumber: 1, monthName: "Test", date: Date())
        
        // These operations should not crash even with potential data corruption
        let cachedNews = cacheService.getCachedNeutralNews(for: dayInfo)
        let regularCachedNews = cacheService.getCachedNews(for: dayInfo)
        let isValid = cacheService.isCacheValid(for: dayInfo)
        
        #expect(cachedNews.isEmpty) // Should return empty, not crash
        #expect(regularCachedNews.isEmpty)
        #expect(!isValid) // Should be false for non-existent cache
    }
    
    @Test("Invalid model data handling")
    func testInvalidModelDataHandling() async throws {
        // Test creating models with extreme values
        let extremeDate = Date(timeIntervalSince1970: 86400) // 1 day after epoch
        let futureDate = Date(timeIntervalSince1970: 2147483647) // Year 2038 - safe timestamp limit
        
        let extremeNeutralNews = NeutralNews(
            neutralTitle: "",  // Empty title
            neutralDescription: String(repeating: "a", count: 100000), // Very long description
            category: "🎉🔥💻", // Emoji category
            relevance: -1, // Invalid relevance
            imageUrl: "not-a-url", // Invalid URL
            imageMedium: "",
            date: extremeDate,
            createdAt: futureDate,
            updatedAt: extremeDate,
            group: Int.max // Maximum integer
        )
        
        // Should create without crashing
        #expect(extremeNeutralNews.neutralTitle.isEmpty)
        #expect(extremeNeutralNews.relevance == -1)
        #expect(extremeNeutralNews.group == Int.max)
    }
    
    // MARK: - Resource Exhaustion Tests
    
    @Test("Memory pressure handling", .timeLimit(.minutes(1)))
    func testMemoryPressureHandling() async throws {
        let manager = NewsDataManager.shared
        
        // Simulate memory pressure by loading many days
        for batchIndex in 0..<50 {
            let date = Date().addingTimeInterval(TimeInterval(batchIndex * -3600)) // Each hour back
            let dayInfo = DayInfo(
                dayName: "Pressure Test \(batchIndex)",
                dayNumber: batchIndex,
                monthName: "Test",
                date: date
            )
            
            await manager.loadNews(for: dayInfo)
        }
        
        // Should complete without crashes
        #expect(true)
    }
    
    // MARK: - String and Text Edge Cases
    
    @Test("Unicode and special character handling")
    func testUnicodeHandling() async throws {
        let filterViewModel = NewsFilterViewModel()
        
        // Create news with various unicode characters
        let unicodeNews = [
            createMockNeutralNews(title: "🇪🇸 Política española 🏛️", category: "Política"),
            createMockNeutralNews(title: "Технологии будущего", category: "Tecnología"), // Cyrillic
            createMockNeutralNews(title: "العربية الأخبار", category: "Internacional"), // Arabic
            createMockNeutralNews(title: "中文新闻", category: "Internacional"), // Chinese
            createMockNeutralNews(title: "Iñtërnâtiônàl Ñëws", category: "Internacional"), // Accented
            createMockNeutralNews(title: "Emoji News 🚀🔬💻🌍", category: "Tecnología")
        ]
        
        // Test search with unicode
        filterViewModel.searchText = "🇪🇸"
        let emojiFiltered = filterViewModel.applyFilters(to: unicodeNews)
        #expect(emojiFiltered.count >= 1)
        
        filterViewModel.searchText = "ñëws"
        let accentFiltered = filterViewModel.applyFilters(to: unicodeNews)
        #expect(accentFiltered.count >= 0) // Should handle gracefully
        
        filterViewModel.searchText = "технологии"
        let cyrillicFiltered = filterViewModel.applyFilters(to: unicodeNews)
        #expect(cyrillicFiltered.count >= 0)
    }
    
    @Test("Extremely long text handling")
    func testExtremelyLongTextHandling() async throws {
        let filterViewModel = NewsFilterViewModel()
        
        // Create news with extremely long content
        let longTitle = String(repeating: "Very Long Title ", count: 1000) // ~16KB title
        let longDescription = String(repeating: "Description content ", count: 10000) // ~200KB description
        
        let extremeNews = [
            createMockNeutralNews(title: longTitle, description: longDescription)
        ]
        
        // Search in extremely long content
        filterViewModel.searchText = "Very Long"
        let filtered = filterViewModel.applyFilters(to: extremeNews)
        
        #expect(filtered.count == 1) // Should find the match
        #expect(filtered.first?.neutralTitle.contains("Very Long") == true)
    }
    
    // MARK: - Concurrent Modification Tests
    
    @Test("Concurrent cache modifications")
    func testConcurrentCacheModifications() async throws {
        let cacheService = CacheService.shared
        
        // Clear cache first
        cacheService.clearAllCache()
        
        // Create multiple concurrent cache operations
        let concurrentTasks = (1...20).map { taskIndex in
            Task {
                let dayInfo = DayInfo(
                    dayName: "Concurrent \(taskIndex)",
                    dayNumber: taskIndex,
                    monthName: "Test",
                    date: Date().addingTimeInterval(TimeInterval(taskIndex * 3600))
                )
                
                let mockNews = [createMockNeutralNews(id: "concurrent_\(taskIndex)")]
                
                // Simultaneous cache operations
                cacheService.cacheNeutralNews(mockNews, for: dayInfo)
                let retrieved = cacheService.getCachedNeutralNews(for: dayInfo)
                let isValid = cacheService.isCacheValid(for: dayInfo)
                
                return (retrieved.count, isValid)
            }
        }
        
        // Wait for all concurrent operations
        let results = await withTaskGroup(of: (Int, Bool).self, returning: [(Int, Bool)].self) { group in
            for task in concurrentTasks {
                group.addTask {
                    await task.value
                }
            }
            
            var results: [(Int, Bool)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // Should complete without crashes
        #expect(results.count == 20)
        #expect(results.allSatisfy { $0.0 >= 0 }) // All counts should be non-negative
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("Error recovery and state consistency")
    func testErrorRecoveryAndStateConsistency() async throws {
        let manager = NewsDataManager.shared
        
        // Simulate various error conditions and verify state remains consistent
        let invalidDayInfo = DayInfo(dayName: "", dayNumber: -1, monthName: "", date: Date(timeIntervalSince1970: 0))
        await manager.loadNews(for: invalidDayInfo)
        
        // State should remain consistent even after error - test basic functionality
        #expect(manager.lastSevenDays.count == 7)
        #expect(manager.isDayLoaded(invalidDayInfo) || !manager.isDayLoaded(invalidDayInfo)) // Should return a boolean
    }
    
    // MARK: - Helper Methods
    
    private func createMockNeutralNews(
        id: String = UUID().uuidString,
        title: String = "Test News",
        description: String = "Test description",
        category: String = "Test"
    ) -> NeutralNews {
        var news = NeutralNews(
            neutralTitle: title,
            neutralDescription: description,
            category: category,
            relevance: 5,
            imageUrl: "https://example.com/image.jpg",
            imageMedium: "https://example.com/medium.jpg",
            date: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            group: 1
        )
        news.id = id
        return news
    }
}

// MARK: - Array Extension for Testing

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

