//
//  ViewModelTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import Testing
@testable import NeutralNews

@Suite("Data Model Tests")
struct DataModelTests {
    
    @Test("NeutralNews sorting by relevance")
    func testNeutralNewsSortingByRelevance() async throws {
        let mockNews = [
            createMockNeutralNews(title: "Low Relevance", relevance: 3),
            createMockNeutralNews(title: "High Relevance", relevance: 9),
            createMockNeutralNews(title: "Medium Relevance", relevance: 6)
        ]
        
        let sortedNews = mockNews.sorted { $0.relevance > $1.relevance }
        
        #expect(sortedNews.count == 3)
        #expect(sortedNews[0].neutralTitle == "High Relevance")
        #expect(sortedNews[1].neutralTitle == "Medium Relevance")  
        #expect(sortedNews[2].neutralTitle == "Low Relevance")
    }
    
    @Test("NeutralNews model initialization")
    func testNeutralNewsInitialization() async throws {
        let mockNews = createMockNeutralNews(title: "Test News", relevance: 5)
        
        #expect(mockNews.neutralTitle == "Test News")
        #expect(mockNews.relevance == 5)
        #expect(!mockNews.id.isEmpty)
        #expect(!mockNews.sourceIds.isEmpty)
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
        let news = NeutralNews(
            id: id,
            neutralTitle: title,
            neutralDescription: "Test description",
            category: category,
            relevance: relevance,
            imageUrl: "https://example.com/image.jpg",
            imageMedium: "https://example.com/medium.jpg",
            date: date,
            createdAt: date,
            updatedAt: date,
            group: group,
            sourceIds: ["test-source-1", "test-source-2"]
        )
        return news
    }
}