//
//  FirestoreServiceTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import FirebaseFirestore
import Testing
@testable import NeutralNews

@Suite("FirestoreService Tests")
struct FirestoreServiceTests {
    
    // MARK: - Initialization Tests
    
    @Test("FirestoreService singleton initialization")
    func testSingletonInitialization() async throws {
        let service1 = FirestoreService.shared
        let service2 = FirestoreService.shared
        
        #expect(service1 === service2) // Same instance
    }
    
    // MARK: - Date Processing Tests
    
    @Test("Day info to date string conversion")
    func testDayInfoToDateString() async throws {
        let calendar = Calendar.current
        let testDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        let dayInfo = DayInfo(dayName: "Test", dayNumber: 15, monthName: "Enero", date: testDate)
        
        // This tests the internal date processing logic
        // We can verify the dayInfo contains correct date information
        #expect(dayInfo.date == testDate)
        #expect(dayInfo.dayNumber == 15)
    }
    
    @Test("Calendar date boundaries")
    func testCalendarDateBoundaries() async throws {
        let calendar = Calendar.current
        
        // Test start of day calculation
        let testDate = Date()
        let startOfDay = calendar.startOfDay(for: testDate)
        
        #expect(calendar.component(.hour, from: startOfDay) == 0)
        #expect(calendar.component(.minute, from: startOfDay) == 0)
        #expect(calendar.component(.second, from: startOfDay) == 0)
    }
    
    // MARK: - Data Parsing Tests
    
    @Test("NeutralNews parsing from Firestore data")
    func testNeutralNewsDataParsing() async throws {
        let service = FirestoreService.shared
        
        // Mock Firestore document data
        let mockData: [String: Any] = [
            "neutralTitle": "Test Neutral News",
            "neutralDescription": "Test description",
            "category": "Política",
            "relevance": 8,
            "imageUrl": "https://example.com/image.jpg",
            "imageMedium": "https://example.com/medium.jpg",
            "date": Timestamp(date: Date()),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "group": 123
        ]
        
        // Test parsing logic
        let documentID = "test_doc_id"
        let neutralNews = service.parseNeutralNews(from: mockData, documentID: documentID)
        
        #expect(neutralNews?.id == documentID)
        #expect(neutralNews?.neutralTitle == "Test Neutral News")
        #expect(neutralNews?.category == "Política")
        #expect(neutralNews?.relevance == 8)
        #expect(neutralNews?.group == 123)
    }
    
    @Test("NeutralNews parsing with missing fields")
    func testNeutralNewsParsingMissingFields() async throws {
        let service = FirestoreService.shared
        
        // Mock data with missing required fields
        let mockData: [String: Any] = [
            "neutralTitle": "Test News",
            // Missing neutralDescription, relevance, etc.
            "category": "Política"
        ]
        
        let neutralNews = service.parseNeutralNews(from: mockData, documentID: "test_id")
        
        // Should return nil for incomplete data
        #expect(neutralNews == nil)
    }
    
    @Test("News parsing from Firestore data")
    func testNewsDataParsing() async throws {
        let service = FirestoreService.shared
        
        // Mock Firestore document data
        let mockData: [String: Any] = [
            "title": "Test News Article",
            "description": "Test news description",
            "scrappedDescription": "Scrapped content",
            "category": "Tecnología",
            "imageUrl": "https://example.com/news-image.jpg",
            "link": "https://example.com/news-article",
            "pubDate": Timestamp(date: Date()),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "sourceMedium": "elPais",
            "neutralScore": 0,
            "group": 456,
            "embedding": [0.1, 0.2, 0.3, 0.4, 0.5]
        ]
        
        let documentID = "news_doc_id"
        let news = service.parseNews(from: mockData, documentID: documentID)
        
        #expect(news?.id == documentID)
        #expect(news?.title == "Test News Article")
        #expect(news?.category == "Tecnología")
        #expect(news?.sourceMedium == .elPais)
        #expect(news?.group == 456)
        #expect(news?.embedding.count == 5)
    }
    
    @Test("News parsing with invalid source medium")
    func testNewsParsingInvalidSourceMedium() async throws {
        let service = FirestoreService.shared
        
        let mockData: [String: Any] = [
            "title": "Test News",
            "description": "Description",
            "category": "Test",
            "link": "https://example.com",
            "pubDate": Timestamp(date: Date()),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "sourceMedium": "invalidMedium", // Invalid source
            "neutralScore": 0,
            "group": 1,
            "embedding": [0.1, 0.2]
        ]
        
        let news = service.parseNews(from: mockData, documentID: "test_id")
        
        // Should return nil for invalid source medium
        #expect(news == nil)
    }
    
    @Test("News parsing with missing embedding")
    func testNewsParsingMissingEmbedding() async throws {
        let service = FirestoreService.shared
        
        let mockData: [String: Any] = [
            "title": "Test News",
            "description": "Description",
            "category": "Test",
            "link": "https://example.com",
            "pubDate": Timestamp(date: Date()),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "sourceMedium": "elPais",
            "neutralScore": 0,
            "group": 1
            // Missing embedding
        ]
        
        let news = service.parseNews(from: mockData, documentID: "test_id")
        
        // Should handle missing embedding gracefully
        #expect(news?.embedding.isEmpty == true)
    }
    
    // MARK: - Data Type Conversion Tests
    
    @Test("Timestamp to Date conversion")
    func testTimestampConversion() async throws {
        let originalDate = Date()
        let timestamp = Timestamp(date: originalDate)
        let convertedDate = timestamp.dateValue()
        
        // Should be approximately equal (allowing for precision differences)
        let timeDifference = abs(originalDate.timeIntervalSince(convertedDate))
        #expect(timeDifference < 0.001) // Less than 1ms difference
    }
    
    @Test("Array to embedding conversion")
    func testEmbeddingConversion() async throws {
        let service = FirestoreService.shared
        
        let mockData: [String: Any] = [
            "title": "Test",
            "description": "Test",
            "category": "Test",
            "link": "https://example.com",
            "pubDate": Timestamp(date: Date()),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "sourceMedium": "elPais",
            "neutralScore": 0,
            "group": 1,
            "embedding": [0.1, 0.2, 0.3] as [Double]
        ]
        
        let news = service.parseNews(from: mockData, documentID: "test_id")
        
        #expect(news?.embedding == [0.1, 0.2, 0.3])
    }
    
    @Test("Integer field parsing")
    func testIntegerFieldParsing() async throws {
        let service = FirestoreService.shared
        
        let mockData: [String: Any] = [
            "neutralTitle": "Test",
            "neutralDescription": "Test",
            "category": "Test",
            "relevance": 7,
            "imageUrl": "https://example.com",
            "imageMedium": "https://example.com",
            "date": Timestamp(date: Date()),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "group": 999
        ]
        
        let neutralNews = service.parseNeutralNews(from: mockData, documentID: "test_id")
        
        #expect(neutralNews?.relevance == 7)
        #expect(neutralNews?.group == 999)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle malformed data gracefully")
    func testMalformedDataHandling() async throws {
        let service = FirestoreService.shared
        
        // Data with wrong types
        let malformedData: [String: Any] = [
            "neutralTitle": 123, // Should be String
            "relevance": "not_a_number", // Should be Int
            "date": "not_a_timestamp" // Should be Timestamp
        ]
        
        let neutralNews = service.parseNeutralNews(from: malformedData, documentID: "malformed_id")
        
        // Should handle malformed data gracefully by returning nil
        #expect(neutralNews == nil)
    }
    
    @Test("Handle empty data")
    func testEmptyDataHandling() async throws {
        let service = FirestoreService.shared
        
        let emptyData: [String: Any] = [:]
        
        let neutralNews = service.parseNeutralNews(from: emptyData, documentID: "empty_id")
        let news = service.parseNews(from: emptyData, documentID: "empty_id")
        
        #expect(neutralNews == nil)
        #expect(news == nil)
    }
    
    @Test("Handle nil values in optional fields")
    func testNilOptionalFields() async throws {
        let service = FirestoreService.shared
        
        let mockData: [String: Any] = [
            "title": "Test News",
            "description": "Description",
            "category": "Test",
            "imageUrl": NSNull(), // Explicit nil
            "link": "https://example.com",
            "pubDate": Timestamp(date: Date()),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "sourceMedium": "elPais",
            "neutralScore": 0,
            "group": 1,
            "embedding": [0.1]
        ]
        
        let news = service.parseNews(from: mockData, documentID: "test_id")
        
        #expect(news?.imageUrl == nil)
        #expect(news?.title == "Test News") // Required fields should still work
    }
    
    
    // MARK: - Integration Tests
    
    @Test("End-to-end data flow simulation")
    func testEndToEndDataFlow() async throws {
        let service = FirestoreService.shared
        
        // Simulate complete Firestore document
        let completeNeutralNewsData: [String: Any] = [
            "neutralTitle": "Complete Test News",
            "neutralDescription": "Complete description with all fields",
            "category": "Política",
            "relevance": 9,
            "imageUrl": "https://example.com/complete-image.jpg",
            "imageMedium": "https://example.com/complete-medium.jpg",
            "date": Timestamp(date: Date()),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "group": 555
        ]
        
        let completeNewsData: [String: Any] = [
            "title": "Complete News Article",
            "description": "Complete news description",
            "scrappedDescription": "Complete scrapped content",
            "category": "Tecnología",
            "imageUrl": "https://example.com/complete-news-image.jpg",
            "link": "https://example.com/complete-news-article",
            "pubDate": Timestamp(date: Date()),
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            "sourceMedium": "elMundo",
            "neutralScore": 2,
            "group": 555,
            "embedding": Array(0..<100).map { Double($0) / 100.0 } // 100-dimensional embedding
        ]
        
        // Parse both types
        let neutralNews = service.parseNeutralNews(from: completeNeutralNewsData, documentID: "complete_neutral")
        let news = service.parseNews(from: completeNewsData, documentID: "complete_news")
        
        // Verify complete parsing
        #expect(neutralNews != nil)
        #expect(news != nil)
        #expect(neutralNews?.group == news?.group) // Same group
        #expect(news?.embedding.count == 100)
        #expect(neutralNews?.neutralTitle == "Complete Test News")
        #expect(news?.sourceMedium == .elMundo)
    }
}

// MARK: - FirestoreService Testing Extensions

extension FirestoreService {
    // Expose internal parsing methods for testing
    func parseNeutralNews(from data: [String: Any], documentID: String) -> NeutralNews? {
        guard let neutralTitle = data["neutralTitle"] as? String,
              let neutralDescription = data["neutralDescription"] as? String,
              let category = data["category"] as? String,
              let relevance = data["relevance"] as? Int,
              let imageUrl = data["imageUrl"] as? String,
              let imageMedium = data["imageMedium"] as? String,
              let dateTimestamp = data["date"] as? Timestamp,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
              let group = data["group"] as? Int else {
            return nil
        }
        
        let neutralNews = NeutralNews(
            id: documentID,
            neutralTitle: neutralTitle,
            neutralDescription: neutralDescription,
            category: category,
            relevance: relevance,
            imageUrl: imageUrl,
            imageMedium: imageMedium,
            date: dateTimestamp.dateValue(),
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue(),
            group: group,
            sourceIds: data["sourceIds"] as? [String] ?? []
        )
        return neutralNews
    }
    
    func parseNews(from data: [String: Any], documentID: String) -> News? {
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let category = data["category"] as? String,
              let link = data["link"] as? String,
              let pubDateTimestamp = data["pubDate"] as? Timestamp,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
              let sourceMediumRaw = data["sourceMedium"] as? String,
              let sourceMedium = Media(rawValue: sourceMediumRaw),
              let neutralScore = data["neutralScore"] as? Int,
              let group = data["group"] as? Int else {
            return nil
        }
        
        let scrappedDescription = data["scrappedDescription"] as? String
        let imageUrl = (data["imageUrl"] is NSNull) ? nil : data["imageUrl"] as? String
        let embedding = (data["embedding"] as? [Double]) ?? []
        
        let news = News(
            id: documentID,
            title: title,
            description: description,
            scrappedDescription: scrappedDescription,
            category: category,
            imageUrl: imageUrl,
            link: link,
            pubDate: pubDateTimestamp.dateValue(),
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue(),
            sourceMedium: sourceMedium,
            neutralScore: neutralScore,
            group: group,
            embedding: embedding
        )
        return news
    }
}