//
//  SavedNewsSourcesPayloadTests.swift
//  NeutralNewsTests
//

import Foundation
import Testing
@testable import NeutralNews

@Suite("Saved News Sources Payload Tests")
struct SavedNewsSourcesPayloadTests {

    @Test("Decode legacy sourceIds array format")
    func decodeLegacySourceIdsFormat() throws {
        let legacyIds = ["source-1", "source-2"]
        let legacyData = try JSONEncoder().encode(legacyIds)
        let legacyString = String(decoding: legacyData, as: UTF8.self)

        let decodedIds = SavedNewsItem.decodeStoredSourceIds(from: legacyString)
        let decodedRelated = SavedNewsItem.decodeStoredRelatedNews(from: legacyString)

        #expect(decodedIds == legacyIds)
        #expect(decodedRelated.isEmpty)
    }

    @Test("Storage key includes region to avoid cross-country collisions")
    func storageKeyIncludesRegion() {
        let usKey = SavedNewsItem.storageKey(newsId: "same-id", regionRaw: "US")
        let esKey = SavedNewsItem.storageKey(newsId: "same-id", regionRaw: "ES")

        #expect(usKey != esKey)
        #expect(usKey == "US|same-id")
        #expect(esKey == "ES|same-id")
    }

    @Test("Encode and decode extended payload with related snapshots")
    func encodeAndDecodeExtendedPayload() {
        let relatedNews = [
            News(
                id: "related-1",
                title: "Related title",
                description: "Related description",
                scrappedDescription: "Source paragraph",
                category: "politics",
                imageUrl: "https://example.com/image.jpg",
                link: "https://example.com/article",
                pubDate: Date(timeIntervalSince1970: 1_700_000_000),
                createdAt: Date(timeIntervalSince1970: 1_700_000_100),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_200),
                publisher: "Example",
                neutralScore: 75,
                group: 42,
                embedding: [0.1, 0.2]
            )
        ]

        let encoded = SavedNewsItem.encodeStoredSources(sourceIds: ["related-1"], relatedNews: relatedNews)
        let decodedIds = SavedNewsItem.decodeStoredSourceIds(from: encoded)
        let decodedRelated = SavedNewsItem.decodeStoredRelatedNews(from: encoded)

        #expect(decodedIds == ["related-1"])
        #expect(decodedRelated.count == 1)
        #expect(decodedRelated.first?.id == "related-1")
        #expect(decodedRelated.first?.title == "Related title")
        #expect(decodedRelated.first?.embedding.isEmpty == true)
    }
}
