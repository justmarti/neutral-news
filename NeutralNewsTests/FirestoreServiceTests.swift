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

    @Test("Fetches archived neutral news from share API")
    func fetchesArchivedNeutralNewsFromShareAPI() async throws {
        let payload = Data("""
        {
          "id": "story-123",
          "neutral_title": "Archived title",
          "neutral_description": "Archived description",
          "category_id": "technology",
          "relevance": 8,
          "date": "2025-04-10T12:00:00",
          "created_at": "2025-04-10T12:01:00",
          "updated_at": "2025-04-10T12:02:00",
          "image_url": "https://example.com/image.jpg",
          "image_medium": "Example",
          "group": 42,
          "source_ids": ["source-1"],
          "sources": []
        }
        """.utf8)
        let session = ArchiveSessionMock(data: payload, statusCode: 200)
        let client = ShareArchiveClient(
            baseURL: URL(string: "https://share.example.com")!,
            session: session
        )

        let snapshot = try await client.fetchArchivedNews(newsId: "story-123", region: .us)

        #expect(session.requestedURL?.absoluteString == "https://share.example.com/api/us/news/story-123")
        #expect(snapshot?.id == "story-123")
        #expect(snapshot?.neutralTitle == "Archived title")
    }

    @Test("Archived news API 404 returns nil")
    func archivedNewsAPI404ReturnsNil() async throws {
        let session = ArchiveSessionMock(data: Data(), statusCode: 404)
        let client = ShareArchiveClient(
            baseURL: URL(string: "https://share.example.com")!,
            session: session
        )

        let snapshot = try await client.fetchArchivedNews(newsId: "missing", region: .es)

        #expect(snapshot?.id == nil)
    }

    @Test("Decodes archived snapshot into deep link navigation payload")
    func decodesArchivedSnapshotIntoDeepLinkNavigationPayload() throws {
        let payload = Data("""
        {
          "id": "42",
          "neutral_title": "Archived title",
          "neutral_description": "Archived description",
          "category_id": "technology",
          "relevance": 8,
          "date": "2025-04-10T12:00:00",
          "created_at": "2025-04-10T12:01:00",
          "updated_at": "2025-04-10T12:02:00",
          "image_url": "https://example.com/image.jpg",
          "image_medium": "Example",
          "group": 42,
          "source_ids": ["source-1"],
          "sources": [
            {
              "id": "source-1",
              "title": "Source title",
              "description_short": "Short description",
              "publisher": "Publisher",
              "link": "https://example.com/source",
              "pub_date": "2025-04-10T11:00:00",
              "image_url": "https://example.com/source.jpg",
              "neutral_score": 7
            }
          ]
        }
        """.utf8)
        let snapshot = try JSONDecoder().decode(ArchivedNewsSnapshot.self, from: payload)
        let lookup = try #require(FirestoreService.decodeArchivedNewsSnapshot(snapshot))

        #expect(lookup.news.id == "42")
        #expect(lookup.news.neutralTitle == "Archived title")
        #expect(lookup.relatedNews.count == 1)
        #expect(lookup.relatedNews.first?.id == "source-1")
        #expect(lookup.relatedNews.first?.embedding == [])
    }

    @Test("Decodes archived snapshot with backend timestamp format")
    func decodesArchivedSnapshotWithBackendTimestampFormat() throws {
        let payload = Data("""
        {
          "id": "1584126",
          "neutral_title": "Archived title",
          "neutral_description": "Archived description",
          "category_id": "society",
          "relevance": 9,
          "date": "2026-04-19T08:23:35",
          "created_at": "2026-04-20T05:06:08.383369",
          "updated_at": "2026-04-20T05:06:08.383369",
          "image_url": "https://example.com/image.jpg",
          "image_medium": "Publisher",
          "group": 1584126,
          "source_ids": ["source-1"],
          "sources": [
            {
              "id": "source-1",
              "title": "Source title",
              "description_short": "Short description",
              "publisher": "Publisher",
              "link": "https://example.com/source",
              "pub_date": "2026-04-19T08:23:35",
              "image_url": "",
              "neutral_score": 7
            }
          ]
        }
        """.utf8)
        let snapshot = try JSONDecoder().decode(ArchivedNewsSnapshot.self, from: payload)
        let lookup = try #require(FirestoreService.decodeArchivedNewsSnapshot(snapshot))

        #expect(lookup.news.id == "1584126")
        #expect(lookup.news.group == 1584126)
        #expect(lookup.news.createdAt.timeIntervalSince1970 > 0)
        #expect(lookup.relatedNews.first?.imageUrl == "")
    }
}

private final class ArchiveSessionMock: URLSessionDataProviding {
    let data: Data
    let statusCode: Int
    private(set) var requestedURL: URL?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func fetchData(from url: URL) async throws -> (Data, URLResponse) {
        requestedURL = url
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
