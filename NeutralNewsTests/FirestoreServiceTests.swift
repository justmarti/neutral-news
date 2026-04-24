import Foundation
import FirebaseFirestore
import Testing
@testable import NeutralNews

@Suite("Firestore Payload Decoding Tests")
struct FirestoreServiceTests {

    @Test("Decodes neutral news payload using production snake_case contract")
    func decodesNeutralNewsPayload() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "neutral_title": "Neutral title",
            "neutral_description": "Neutral description",
            "category_id": "technology",
            "relevance": 8,
            "image_url": "https://example.com/image.jpg",
            "image_medium": "Example",
            "date": Timestamp(date: now),
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "group": 42,
            "source_ids": ["source-1", "source-2"]
        ]

        let news = FirestoreService.decodeNeutralNews(from: payload, documentID: "neutral-1")

        #expect(news?.id == "neutral-1")
        #expect(news?.neutralTitle == "Neutral title")
        #expect(news?.category == "technology")
        #expect(news?.sourceIds == ["source-1", "source-2"])
        #expect(news?.group == 42)
    }

    @Test("Decodes story focus point metadata when present")
    func decodesNeutralNewsStoryFocusPointMetadata() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "neutral_title": "Neutral title",
            "neutral_description": "Neutral description",
            "category_id": "technology",
            "relevance": 8,
            "image_url": "https://example.com/image.jpg",
            "image_medium": "Example",
            "story_focus_point": [
                "x": 0.62,
                "y": 0.44,
            ],
            "date": Timestamp(date: now),
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "group": 42,
            "source_ids": ["source-1", "source-2"]
        ]

        let news = FirestoreService.decodeNeutralNews(from: payload, documentID: "neutral-1")

        #expect(news?.storyFocusPoint?.x == 0.62)
        #expect(news?.storyFocusPoint?.y == 0.44)
    }

    @Test("Falls back to legacy story crop metadata when focus point is absent")
    func decodesNeutralNewsLegacyStoryCropAsFocusPoint() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "neutral_title": "Neutral title",
            "neutral_description": "Neutral description",
            "category_id": "technology",
            "relevance": 8,
            "image_url": "https://example.com/image.jpg",
            "image_medium": "Example",
            "story_crop": [
                "x": 0.1,
                "y": 0.1,
                "width": 0.5,
                "height": 0.7,
            ],
            "date": Timestamp(date: now),
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "group": 42,
            "source_ids": ["source-1", "source-2"]
        ]

        let news = FirestoreService.decodeNeutralNews(from: payload, documentID: "neutral-1")

        #expect(news?.storyFocusPoint?.x == 0.35)
        #expect(news?.storyFocusPoint?.y == 0.45)
    }

    @Test("Decodes neutral news category from legacy fallback field")
    func decodesNeutralNewsCategoryFallback() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "neutral_title": "Neutral title",
            "neutral_description": "Neutral description",
            "category": "politica",
            "relevance": 8,
            "image_url": "https://example.com/image.jpg",
            "image_medium": "Example",
            "date": Timestamp(date: now),
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "group": 42,
            "source_ids": ["source-1"]
        ]

        let news = FirestoreService.decodeNeutralNews(from: payload, documentID: "neutral-1")

        #expect(news?.category == "politica")
    }

    @Test("Rejects neutral news payload when source identifiers are missing")
    func rejectsNeutralNewsPayloadWithoutSourceIds() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "neutral_title": "Neutral title",
            "neutral_description": "Neutral description",
            "category_id": "technology",
            "relevance": 8,
            "image_url": "https://example.com/image.jpg",
            "image_medium": "Example",
            "date": Timestamp(date: now),
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "group": 42
        ]

        let news = FirestoreService.decodeNeutralNews(from: payload, documentID: "neutral-1")

        #expect(news == nil)
    }

    @Test("Rejects neutral news payload when a required timestamp is missing")
    func rejectsNeutralNewsPayloadWithoutCreatedAt() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "neutral_title": "Neutral title",
            "neutral_description": "Neutral description",
            "category_id": "technology",
            "relevance": 8,
            "image_url": "https://example.com/image.jpg",
            "image_medium": "Example",
            "date": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "group": 42,
            "source_ids": ["source-1"]
        ]

        let news = FirestoreService.decodeNeutralNews(from: payload, documentID: "neutral-1")

        #expect(news == nil)
    }

    @Test("Decodes regular news payload and preserves optional fields")
    func decodesRegularNewsPayload() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "title": "News title",
            "description_short": "Short description",
            "scrapped_description": "Longer body",
            "group": 42,
            "category_id": "business",
            "link": "https://example.com/article",
            "pub_date": Timestamp(date: now),
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "neutral_score": 55,
            "publisher": "Example",
            "image_url": "https://example.com/image.jpg",
            "embedding": [0.1, 0.2, 0.3]
        ]

        let news = FirestoreService.decodeNews(from: payload, documentID: "news-1")

        #expect(news?.id == "news-1")
        #expect(news?.description == "Short description")
        #expect(news?.scrappedDescription == "Longer body")
        #expect(news?.category == "business")
        #expect(news?.embedding == [0.1, 0.2, 0.3])
    }

    @Test("Decodes regular news using legacy category fallback and default embedding")
    func decodesRegularNewsFallbackFields() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "title": "News title",
            "description_short": "Short description",
            "group": 42,
            "category": "economia",
            "link": "https://example.com/article",
            "pub_date": Timestamp(date: now),
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "neutral_score": 55,
            "publisher": "Example"
        ]

        let news = FirestoreService.decodeNews(from: payload, documentID: "news-1")

        #expect(news?.category == "economia")
        #expect(news?.embedding.isEmpty == true)
        #expect(news?.imageUrl == nil)
    }

    @Test("Rejects malformed regular news payload")
    func rejectsMalformedRegularNewsPayload() {
        let payload: [String: Any] = [
            "title": "News title",
            "description_short": 123,
            "group": 42
        ]

        let news = FirestoreService.decodeNews(from: payload, documentID: "news-1")

        #expect(news == nil)
    }

    @Test("Rejects regular news payload when publisher is missing")
    func rejectsRegularNewsPayloadWithoutPublisher() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "title": "News title",
            "description_short": "Short description",
            "group": 42,
            "category_id": "business",
            "link": "https://example.com/article",
            "pub_date": Timestamp(date: now),
            "created_at": Timestamp(date: now),
            "updated_at": Timestamp(date: now),
            "neutral_score": 55
        ]

        let news = FirestoreService.decodeNews(from: payload, documentID: "news-1")

        #expect(news == nil)
    }

    @Test("Problem report values stay aligned with report payload contract")
    func problemReportValuesStayAligned() {
        #expect(Problem.newsRepeated.firestoreValue == "news_repeated")
        #expect(Problem.newsRepeated.localizedTitle == String(localized: Problem.newsRepeated.title))
        #expect(Problem.notRelatedNews.firestoreValue == "not_related_news")
    }
}
