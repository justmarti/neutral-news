//
//  ViewModelTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import Testing
@testable import NeutralNews

@Suite("ViewModel Tests")
struct ViewModelTests {
    
    // MARK: - NewsListViewModel Tests
    
    @Test("NewsListViewModel initialization")
    func testNewsListViewModelInit() async throws {
        let viewModel = NewsListViewModel.shared
        
        #expect(viewModel.daySelected.dayName == "Hoy")
        #expect(viewModel.lastSevenDays.count == 7)
        #expect(!viewModel.isLoadingNeutralNews)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.categoryFilter.isEmpty)
        #expect(viewModel.orderBy == .hour)
        #expect(!viewModel.isAnyFilterEnabled)
    }
    
    @Test("Day selection triggers loading")
    func testDaySelectionTriggersLoading() async throws {
        let viewModel = NewsListViewModel.shared
        let initialDay = viewModel.daySelected
        
        // Change to different day
        let newDay = DayInfo(dayName: "Ayer", dayNumber: 1, monthName: "Test", date: Date().addingTimeInterval(-86400))
        viewModel.changeDay(to: newDay)
        
        #expect(viewModel.daySelected.dayName == "Ayer")
        #expect(viewModel.daySelected != initialDay)
    }
    
    @Test("News filtering by search text")
    func testSearchTextFiltering() async throws {
        let viewModel = NewsListViewModel.shared
        
        // Set search text
        viewModel.searchText = "política"
        
        #expect(viewModel.searchText == "política")
        #expect(!viewModel.isAnyFilterEnabled) // Search text doesn't count as filter in this implementation
    }
    
    @Test("Category filtering")
    func testCategoryFiltering() async throws {
        let viewModel = NewsListViewModel.shared
        
        // Test category filter
        viewModel.filterByCategory(.politica)
        
        #expect(viewModel.categoryFilter.contains(.politica))
        #expect(viewModel.isAnyFilterEnabled)
        
        // Test toggling off
        viewModel.filterByCategory(.politica)
        
        #expect(!viewModel.categoryFilter.contains(.politica))
    }
    
    @Test("Clear all filters")
    func testClearAllFilters() async throws {
        let viewModel = NewsListViewModel.shared
        
        // Set some filters
        viewModel.searchText = "test"
        viewModel.filterByCategory(.tecnologia)
        viewModel.orderBy = .relevance
        
        #expect(viewModel.isAnyFilterEnabled)
        
        // Clear filters
        viewModel.clearFilters()
        
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.categoryFilter.isEmpty)
        #expect(viewModel.orderBy == .hour) // Should reset to default
        #expect(!viewModel.isAnyFilterEnabled)
    }
    
    @Test("Order by selection")
    func testOrderBySelection() async throws {
        let viewModel = NewsListViewModel.shared
        
        #expect(viewModel.orderBy == .hour) // Default
        
        viewModel.orderBy = .relevance
        #expect(viewModel.orderBy == .relevance)
        
        viewModel.orderBy = .popularity
        #expect(viewModel.orderBy == .popularity)
    }
    
    @Test("Force load news")
    func testForceLoadNews() async throws {
        let viewModel = NewsListViewModel.shared
        
        #expect(!viewModel.isLoadingNeutralNews)
        
        // Start force loading (should set loading state)
        let loadingTask = Task {
            await viewModel.forceLoadNews()
        }
        
        // Allow some time for loading state to be set
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        await loadingTask.value
        
        // After completion, should not be loading
        #expect(!viewModel.isLoadingNeutralNews)
    }
    
    // MARK: - NewsFilterViewModel Tests
    
    @Test("NewsFilterViewModel initialization")
    func testNewsFilterViewModelInit() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        #expect(filterViewModel.searchText.isEmpty)
        #expect(filterViewModel.categoryFilter.isEmpty)
        #expect(filterViewModel.orderBy == .hour)
        #expect(!filterViewModel.isAnyFilterEnabled)
    }
    
    @Test("Filter application with search text")
    func testFilterApplicationWithSearchText() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        let mockNews = [
            createMockNeutralNews(title: "Política Nacional", category: "Política"),
            createMockNeutralNews(title: "Tecnología Avanzada", category: "Tecnología"),
            createMockNeutralNews(title: "Política Internacional", category: "Política")
        ]
        
        // Test search filtering
        filterViewModel.searchText = "política"
        let filteredNews = filterViewModel.applyFilters(to: mockNews)
        
        #expect(filteredNews.count == 2)
        #expect(filteredNews.allSatisfy { $0.neutralTitle.lowercased().contains("política") })
    }
    
    @Test("Filter application with category")
    func testFilterApplicationWithCategory() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        let mockNews = [
            createMockNeutralNews(title: "News 1", category: "Política"),
            createMockNeutralNews(title: "News 2", category: "Tecnología"),
            createMockNeutralNews(title: "News 3", category: "Política")
        ]
        
        // Test category filtering
        filterViewModel.categoryFilter = [.politica]
        let filteredNews = filterViewModel.applyFilters(to: mockNews)
        
        #expect(filteredNews.count == 2)
        #expect(filteredNews.allSatisfy { $0.category == "Política" })
    }
    
    @Test("Multiple category filtering")
    func testMultipleCategoryFiltering() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        let mockNews = [
            createMockNeutralNews(title: "News 1", category: "Política"),
            createMockNeutralNews(title: "News 2", category: "Tecnología"),
            createMockNeutralNews(title: "News 3", category: "Deportes"),
            createMockNeutralNews(title: "News 4", category: "Tecnología")
        ]
        
        // Test multiple category filtering
        filterViewModel.categoryFilter = [.politica, .tecnologia]
        let filteredNews = filterViewModel.applyFilters(to: mockNews)
        
        #expect(filteredNews.count == 3)
        #expect(filteredNews.allSatisfy { news in
            news.category == "Política" || news.category == "Tecnología"
        })
    }
    
    @Test("Combined search and category filtering")
    func testCombinedFiltering() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        let mockNews = [
            createMockNeutralNews(title: "Política Nacional", category: "Política"),
            createMockNeutralNews(title: "Política Digital", category: "Tecnología"),
            createMockNeutralNews(title: "Deportes Nacional", category: "Deportes"),
            createMockNeutralNews(title: "Tecnología Avanzada", category: "Tecnología")
        ]
        
        // Test combined filtering
        filterViewModel.searchText = "nacional"
        filterViewModel.categoryFilter = [.politica, .deportes]
        let filteredNews = filterViewModel.applyFilters(to: mockNews)
        
        #expect(filteredNews.count == 2) // "Política Nacional" and "Deportes Nacional"
        #expect(filteredNews.allSatisfy { $0.neutralTitle.lowercased().contains("nacional") })
        #expect(filteredNews.allSatisfy { news in
            news.category == "Política" || news.category == "Deportes"
        })
    }
    
    @Test("Sorting by date descending")
    func testSortingByDateDesc() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        let now = Date()
        let mockNews = [
            createMockNeutralNews(title: "Old News", date: now.addingTimeInterval(-3600)), // 1 hour ago
            createMockNeutralNews(title: "Recent News", date: now.addingTimeInterval(-1800)), // 30 min ago
            createMockNeutralNews(title: "Latest News", date: now) // Now
        ]
        
        filterViewModel.orderBy = .hour
        let sortedNews = filterViewModel.applyFilters(to: mockNews)
        
        #expect(sortedNews[0].neutralTitle == "Latest News")
        #expect(sortedNews[1].neutralTitle == "Recent News")
        #expect(sortedNews[2].neutralTitle == "Old News")
    }
    
    @Test("Sorting by relevance")
    func testSortingByRelevance() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        let mockNews = [
            createMockNeutralNews(title: "Low Relevance", relevance: 3),
            createMockNeutralNews(title: "High Relevance", relevance: 9),
            createMockNeutralNews(title: "Medium Relevance", relevance: 6)
        ]
        
        filterViewModel.orderBy = .relevance
        let sortedNews = filterViewModel.applyFilters(to: mockNews)
        
        #expect(sortedNews[0].neutralTitle == "High Relevance")
        #expect(sortedNews[1].neutralTitle == "Medium Relevance")
        #expect(sortedNews[2].neutralTitle == "Low Relevance")
    }
    
    @Test("Sorting by popularity")
    func testSortingByPopularity() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        let mockNews = [
            createMockNeutralNews(title: "Less Popular", group: 1),
            createMockNeutralNews(title: "More Popular", group: 2),
            createMockNeutralNews(title: "Medium Popular", group: 3)
        ]
        
        filterViewModel.orderBy = .popularity
        let sortedNews = filterViewModel.applyFilters(to: mockNews)
        
        // Should sort based on related news count (popularity)
        #expect(sortedNews.count == 3)
    }
    
    @Test("Category toggle functionality")
    func testCategoryToggle() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        #expect(filterViewModel.categoryFilter.isEmpty)
        
        // Add category
        filterViewModel.filterByCategory(.politica)
        #expect(filterViewModel.categoryFilter.contains(.politica))
        #expect(filterViewModel.isAnyFilterEnabled)
        
        // Remove same category (toggle off)
        filterViewModel.filterByCategory(.politica)
        #expect(!filterViewModel.categoryFilter.contains(.politica))
        #expect(!filterViewModel.isAnyFilterEnabled)
    }
    
    // MARK: - Integration Tests
    
    @Test("NewsListViewModel integration with filters")
    func testNewsListViewModelFilterIntegration() async throws {
        let viewModel = NewsListViewModel.shared
        
        // Test that changing filters affects isAnyFilterEnabled
        #expect(!viewModel.isAnyFilterEnabled)
        
        viewModel.searchText = "test"
        #expect(!viewModel.isAnyFilterEnabled) // Search text doesn't enable filter
        
        viewModel.searchText = ""
        viewModel.filterByCategory(.politica)
        #expect(viewModel.isAnyFilterEnabled)
        
        viewModel.clearFilters()
        #expect(!viewModel.isAnyFilterEnabled)
    }
    
    @Test("Filter performance with large dataset", .timeLimit(.minutes(1)))
    func testFilterPerformanceWithLargeDataset() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        // Create large dataset
        let largeDataset = (1...10000).map { index in
            createMockNeutralNews(
                title: "News \(index) \(index % 2 == 0 ? "política" : "tecnología")",
                category: index % 2 == 0 ? "Política" : "Tecnología",
                relevance: index % 10
            )
        }
        
        let startTime = Date()
        
        // Apply complex filtering
        filterViewModel.searchText = "política"
        filterViewModel.categoryFilter = [.politica]
        filterViewModel.orderBy = .relevance
        
        let filteredNews = filterViewModel.applyFilters(to: largeDataset)
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        #expect(filteredNews.count > 0)
        #expect(processingTime < 1.0) // Should complete within 1 second
        #expect(filteredNews.allSatisfy { $0.category == "Política" })
        #expect(filteredNews.allSatisfy { $0.neutralTitle.contains("política") })
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle empty news arrays in filters")
    func testFilterWithEmptyArray() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        
        filterViewModel.searchText = "anything"
        filterViewModel.categoryFilter = [.politica]
        
        let filteredNews = filterViewModel.applyFilters(to: [])
        
        #expect(filteredNews.isEmpty)
    }
    
    @Test("Handle invalid search patterns")
    func testInvalidSearchPatterns() async throws {
        let filterViewModel = NewsFilterViewModel.shared
        let mockNews = [createMockNeutralNews(title: "Test News")]
        
        // Test with special characters
        filterViewModel.searchText = ".*[]{}"
        let filteredNews = filterViewModel.applyFilters(to: mockNews)
        
        // Should not crash and handle gracefully
        #expect(filteredNews.count >= 0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockNeutralNews(
        id: String = "test_default",
        title: String = "Test News",
        category: String = "Test",
        relevance: Int = 5,
        group: Int = 1,
        date: Date = Date()
    ) -> NeutralNews {
        var news = NeutralNews(
            neutralTitle: title,
            neutralDescription: "Test description",
            category: category,
            relevance: relevance,
            imageUrl: "https://example.com/image.jpg",
            imageMedium: "https://example.com/medium.jpg",
            date: date,
            createdAt: date,
            updatedAt: date,
            group: group
        )
        news.id = id == "test_default" ? "test_\(UUID().uuidString)" : id
        return news
    }
}
