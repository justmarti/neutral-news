import Foundation
import Testing
@testable import NeutralNews

@Suite("Widget Briefing Builder Tests")
struct WidgetBriefingBuilderTests {
    @Test("Filters stories outside the last 24 hours")
    func filtersStoriesOutsideLast24Hours() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let recentStory = makeWidgetNews(id: "recent", title: "Recent", relevance: 1, date: referenceDate.addingTimeInterval(-60))
        let oldStory = makeWidgetNews(id: "old", title: "Old", relevance: 99, date: referenceDate.addingTimeInterval(-86_401))

        let snapshot = WidgetBriefingBuilder.buildSnapshot(
            from: [oldStory, recentStory],
            region: "US",
            referenceDate: referenceDate
        )

        #expect(snapshot?.items.map(\.id) == ["recent"])
    }

    @Test("Prioritizes by relevance")
    func prioritizesByRelevance() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let low = makeWidgetNews(id: "low", title: "Low", relevance: 1, date: referenceDate)
        let high = makeWidgetNews(id: "high", title: "High", relevance: 10, date: referenceDate.addingTimeInterval(-60))

        let snapshot = WidgetBriefingBuilder.buildSnapshot(
            from: [low, high],
            region: "US",
            referenceDate: referenceDate
        )

        #expect(snapshot?.items.map(\.id) == ["high", "low"])
    }

    @Test("Breaks relevance ties by date")
    func breaksRelevanceTiesByDate() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let older = makeWidgetNews(id: "older", title: "Older", relevance: 5, date: referenceDate.addingTimeInterval(-120))
        let newer = makeWidgetNews(id: "newer", title: "Newer", relevance: 5, date: referenceDate.addingTimeInterval(-60))

        let snapshot = WidgetBriefingBuilder.buildSnapshot(
            from: [older, newer],
            region: "US",
            referenceDate: referenceDate
        )

        #expect(snapshot?.items.map(\.id) == ["newer", "older"])
    }

    @Test("Limits snapshot to five stories")
    func limitsSnapshotToFiveStories() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let news = (0..<7).map { index in
            makeWidgetNews(
                id: "story-\(index)",
                title: "Story \(index)",
                relevance: 10 - index,
                date: referenceDate.addingTimeInterval(TimeInterval(-index))
            )
        }

        let snapshot = WidgetBriefingBuilder.buildSnapshot(
            from: news,
            region: "US",
            referenceDate: referenceDate
        )

        #expect(snapshot?.items.map(\.id) == ["story-0", "story-1", "story-2", "story-3", "story-4"])
    }

    @Test("Uses id as final stable sort key")
    func usesIDAsFinalStableSortKey() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let second = makeWidgetNews(id: "story-b", title: "Story B", relevance: 7, date: referenceDate)
        let first = makeWidgetNews(id: "story-a", title: "Story A", relevance: 7, date: referenceDate)

        let snapshot = WidgetBriefingBuilder.buildSnapshot(
            from: [second, first],
            region: "ES",
            referenceDate: referenceDate
        )

        #expect(snapshot?.items.map(\.id) == ["story-a", "story-b"])
    }
}

private struct TestWidgetNews: WidgetBriefingNews {
    let id: String
    let neutralTitle: String
    let imageUrl: String
    let date: Date
    let relevance: Int
}

private func makeWidgetNews(
    id: String,
    title: String,
    relevance: Int,
    date: Date
) -> TestWidgetNews {
    TestWidgetNews(
        id: id,
        neutralTitle: title,
        imageUrl: "https://example.com/\(id).jpg",
        date: date,
        relevance: relevance
    )
}
