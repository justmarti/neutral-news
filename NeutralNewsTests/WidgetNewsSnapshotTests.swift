import Foundation
import Testing
@testable import NeutralNews

@Suite("Widget News Snapshot Tests")
struct WidgetNewsSnapshotTests {
    @Test("Codable round trip preserves snapshot")
    func codableRoundTripPreservesSnapshot() throws {
        let snapshot = WidgetNewsSnapshot(
            generatedAt: Date(timeIntervalSince1970: 2_000_000),
            region: "US",
            items: [
                WidgetNewsItem(
                    id: "story-1",
                    title: "Story One",
                    imageURL: URL(string: "https://example.com/story-1.jpg"),
                    date: Date(timeIntervalSince1970: 1_999_900),
                    relevance: 9
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSnapshot = try decoder.decode(WidgetNewsSnapshot.self, from: data)

        #expect(decodedSnapshot == snapshot)
    }

    @Test("Decodes remote widget snapshot contract")
    func decodesRemoteWidgetSnapshotContract() async throws {
        let payload = """
        {
          "schemaVersion": 1,
          "generatedAt": "1970-01-24T03:33:20Z",
          "region": "US",
          "items": [
            {
              "id": "story-1",
              "title": "Story One",
              "imageURL": "https://example.com/story-1.jpg",
              "date": "1970-01-24T03:31:40Z",
              "relevance": 9
            }
          ]
        }
        """
        let data = try #require(payload.data(using: .utf8))
        let response = try #require(HTTPURLResponse(
            url: WidgetSnapshotConstants.remoteSnapshotURL(for: "US"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        let client = WidgetRemoteSnapshotClient { request in
            #expect(request.url?.absoluteString == "https://share.getfacts.app/api/us/widgets/daily-briefing")
            return (data, response)
        }

        let snapshot = try await client.fetchSnapshot(
            for: "US",
            referenceDate: Date(timeIntervalSince1970: 2_000_010)
        )

        #expect(snapshot?.schemaVersion == 1)
        #expect(snapshot?.region == "US")
        #expect(snapshot?.items.map(\.id) == ["story-1"])
        #expect(snapshot?.items.first?.imageURL?.absoluteString == "https://example.com/story-1.jpg")
    }

    @Test("Normalizes HTML escaped image URLs")
    func normalizesHTMLEscapedImageURLs() throws {
        let payload = """
        {
          "schemaVersion": 1,
          "generatedAt": "1970-01-24T03:33:20Z",
          "region": "ES",
          "items": [
            {
              "id": "story-1",
              "title": "Story One",
              "imageURL": "https://example.com/story.jpg?width=1200&amp;height=675&amp;format=webply",
              "date": "1970-01-24T03:31:40Z",
              "relevance": 9
            }
          ]
        }
        """

        let data = try #require(payload.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(WidgetNewsSnapshot.self, from: data)

        #expect(snapshot.items.first?.imageURL?.absoluteString == "https://example.com/story.jpg?width=1200&height=675&format=webply")
    }

    @Test("Rejects stale widget snapshots")
    func rejectsStaleWidgetSnapshots() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let snapshot = WidgetNewsSnapshot(
            generatedAt: referenceDate.addingTimeInterval(-WidgetSnapshotConstants.snapshotFreshnessInterval - 1),
            region: "US",
            items: [
                WidgetNewsItem(
                    id: "story-1",
                    title: "Story One",
                    imageURL: nil,
                    date: referenceDate,
                    relevance: 9
                )
            ]
        )

        #expect(snapshot.isFresh(referenceDate: referenceDate) == false)
    }

    @Test("Remote client rejects stale widget snapshots")
    func remoteClientRejectsStaleWidgetSnapshots() async throws {
        let payload = """
        {
          "schemaVersion": 1,
          "generatedAt": "1970-01-24T03:33:20Z",
          "region": "ES",
          "items": [
            {
              "id": "story-1",
              "title": "Story One",
              "imageURL": "https://example.com/story-1.jpg",
              "date": "1970-01-24T03:31:40Z",
              "relevance": 9
            }
          ]
        }
        """
        let data = try #require(payload.data(using: .utf8))
        let response = try #require(HTTPURLResponse(
            url: WidgetSnapshotConstants.remoteSnapshotURL(for: "ES"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        let client = WidgetRemoteSnapshotClient { _ in
            (data, response)
        }

        let snapshot = try await client.fetchSnapshot(
            for: "ES",
            referenceDate: Date(timeIntervalSince1970: 3_000_000)
        )

        #expect(snapshot == nil)
    }

    @Test("Rotates through every available story without dropping image-less items")
    func rotatesThroughEveryAvailableStory() {
        let items = [
            WidgetNewsItem(id: "with-image", title: "With image", imageURL: URL(string: "https://example.com/1.jpg"), date: .now, relevance: 3),
            WidgetNewsItem(id: "without-image", title: "Without image", imageURL: nil, date: .now, relevance: 2),
            WidgetNewsItem(id: "last", title: "Last", imageURL: URL(string: "https://example.com/3.jpg"), date: .now, relevance: 1)
        ]
        let snapshot = WidgetNewsSnapshot(generatedAt: .now, region: "ES", items: items)

        #expect(snapshot.rotatingItems(startingAt: 1, count: 2).map(\.id) == ["without-image", "last"])
        #expect(snapshot.rotatingItems(startingAt: 2, count: 2).map(\.id) == ["last", "with-image"])
    }

    @Test("Builds Spain widget deep link")
    func buildsSpainWidgetDeepLink() {
        let item = WidgetNewsItem(id: "story-1", title: "Story One", imageURL: nil, date: .now, relevance: 1)

        let url = WidgetDeepLink.url(for: item, region: "ES")

        #expect(url?.absoluteString == "neutralnews://es/news/story-1")
    }

    @Test("Builds United States widget deep link")
    func buildsUnitedStatesWidgetDeepLink() {
        let item = WidgetNewsItem(id: "story-2", title: "Story Two", imageURL: nil, date: .now, relevance: 1)

        let url = WidgetDeepLink.url(for: item, region: "US")

        #expect(url?.absoluteString == "neutralnews://us/news/story-2")
    }

}
