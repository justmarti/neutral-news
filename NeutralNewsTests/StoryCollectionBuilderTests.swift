//
//  StoryCollectionBuilderTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 4/20/26.
//

import Foundation
import Testing
@testable import NeutralNews

@Suite("Story Collection Builder Tests")
struct StoryCollectionBuilderTests {
    @Test("Builds the briefing from the top eight relevant stories in the last 24 hours ordered by date")
    func buildsBriefingFromTopEightRelevantStoriesInLast24HoursOrderedByDate() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let topOlder = makeStoryCollectionNews(id: "top-older", title: "Top Older", categoryRawValue: "world", relevance: 10, date: referenceDate.addingTimeInterval(-120))
        let topNewer = makeStoryCollectionNews(id: "top-newer", title: "Top Newer", categoryRawValue: "world", relevance: 10, date: referenceDate.addingTimeInterval(-60))
        let relevance9 = makeStoryCollectionNews(id: "relevance-9", title: "Relevance 9", categoryRawValue: "politics", relevance: 9, date: referenceDate.addingTimeInterval(-300))
        let relevance8 = makeStoryCollectionNews(id: "relevance-8", title: "Relevance 8", categoryRawValue: "technology", relevance: 8, date: referenceDate.addingTimeInterval(-400))
        let relevance7 = makeStoryCollectionNews(id: "relevance-7", title: "Relevance 7", categoryRawValue: "business", relevance: 7, date: referenceDate.addingTimeInterval(-500))
        let relevance6 = makeStoryCollectionNews(id: "relevance-6", title: "Relevance 6", categoryRawValue: "world", relevance: 6, date: referenceDate.addingTimeInterval(-600))
        let boundary = makeStoryCollectionNews(id: "boundary", title: "Boundary", categoryRawValue: "world", relevance: 5, date: referenceDate.addingTimeInterval(-86_400))
        let relevance4 = makeStoryCollectionNews(id: "relevance-4", title: "Relevance 4", categoryRawValue: "politics", relevance: 4, date: referenceDate.addingTimeInterval(-700))
        let relevance3 = makeStoryCollectionNews(id: "relevance-3", title: "Relevance 3", categoryRawValue: "politics", relevance: 3, date: referenceDate.addingTimeInterval(-800))
        let oldImportant = makeStoryCollectionNews(id: "old-important", title: "Old Important", categoryRawValue: "world", relevance: 99, date: referenceDate.addingTimeInterval(-86_401))

        let news = [
            relevance3,
            relevance4,
            oldImportant,
            boundary,
            relevance6,
            relevance7,
            relevance8,
            relevance9,
            topOlder,
            topNewer
        ]

        let briefingCollection = StoryCollectionBuilder.buildBriefingCollection(
            news: news,
            referenceDate: referenceDate
        )

        #expect(briefingCollection?.coverNews.id == "top-newer")
        #expect(briefingCollection?.items.map(\.id) == [
            "top-newer",
            "top-older",
            "relevance-9",
            "relevance-8",
            "relevance-7",
            "relevance-6",
            "relevance-4",
            "boundary"
        ])
    }

    @Test("Keeps relevant late yesterday stories over less relevant recent stories")
    func keepsRelevantLateYesterdayStoriesOverLessRelevantRecentStories() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let relevantYesterday = makeStoryCollectionNews(id: "relevant-yesterday", title: "Relevant Yesterday", categoryRawValue: "world", relevance: 9, date: referenceDate.addingTimeInterval(-10 * 60 * 60))
        let recentLowRelevance = makeStoryCollectionNews(id: "recent-low", title: "Recent Low", categoryRawValue: "world", relevance: 1, date: referenceDate.addingTimeInterval(-60))

        var news = [relevantYesterday, recentLowRelevance]
        for index in 0..<7 {
            news.append(
                makeStoryCollectionNews(
                    id: "recent-\(index)",
                    title: "Recent \(index)",
                    categoryRawValue: "politics",
                    relevance: 8,
                    date: referenceDate.addingTimeInterval(TimeInterval(-(index + 2) * 60))
                )
            )
        }

        let briefingCollection = StoryCollectionBuilder.buildBriefingCollection(
            news: news,
            referenceDate: referenceDate
        )

        #expect(briefingCollection?.items.contains(where: { $0.id == "relevant-yesterday" }) == true)
        #expect(briefingCollection?.items.contains(where: { $0.id == "recent-low" }) == false)
    }

    @Test("Uses relevance as a tie breaker for stories with the same date")
    func usesRelevanceAsTieBreakerForStoriesWithSameDate() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let sameDateLowerRelevance = makeStoryCollectionNews(id: "same-date-lower", title: "Same Date Lower", categoryRawValue: "world", relevance: 6, date: referenceDate.addingTimeInterval(-60))
        let sameDateHigherRelevance = makeStoryCollectionNews(id: "same-date-higher", title: "Same Date Higher", categoryRawValue: "world", relevance: 9, date: referenceDate.addingTimeInterval(-60))
        let olderHighestRelevance = makeStoryCollectionNews(id: "older-highest", title: "Older Highest", categoryRawValue: "politics", relevance: 10, date: referenceDate.addingTimeInterval(-120))

        let briefingCollection = StoryCollectionBuilder.buildBriefingCollection(
            news: [
                olderHighestRelevance,
                sameDateLowerRelevance,
                sameDateHigherRelevance
            ],
            referenceDate: referenceDate
        )

        #expect(briefingCollection?.items.map(\.id) == [
            "same-date-higher",
            "same-date-lower",
            "older-highest"
        ])
    }

    @Test("Uses id as a final tie breaker")
    func usesIDAsFinalTieBreaker() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let secondByID = makeStoryCollectionNews(id: "story-b", title: "Story B", categoryRawValue: "world", relevance: 8, date: referenceDate.addingTimeInterval(-60))
        let firstByID = makeStoryCollectionNews(id: "story-a", title: "Story A", categoryRawValue: "world", relevance: 8, date: referenceDate.addingTimeInterval(-60))

        let briefingCollection = StoryCollectionBuilder.buildBriefingCollection(
            news: [
                secondByID,
                firstByID
            ],
            referenceDate: referenceDate
        )

        #expect(briefingCollection?.items.map(\.id) == [
            "story-a",
            "story-b"
        ])
    }

    @Test("Orders selected stories by recency")
    func ordersSelectedStoriesByRecency() throws {
        let calendar = Calendar.current
        let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 9)))
        let lateYesterday = makeStoryCollectionNews(id: "late-yesterday", title: "Late Yesterday", categoryRawValue: "world", relevance: 9, date: referenceDate.addingTimeInterval(-10 * 60 * 60))
        let morningStory = makeStoryCollectionNews(id: "morning-story", title: "Morning Story", categoryRawValue: "politics", relevance: 8, date: referenceDate.addingTimeInterval(-60 * 60))

        let briefingCollection = StoryCollectionBuilder.buildBriefingCollection(
            news: [morningStory, lateYesterday],
            referenceDate: referenceDate
        )

        #expect(briefingCollection?.items.map(\.id) == ["morning-story", "late-yesterday"])
    }

    @Test("Returns nil when there are no stories inside the last 24 hours")
    func returnsNilWhenThereAreNoStoriesInsideLast24Hours() {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000)
        let oldStory = makeStoryCollectionNews(id: "old-story", title: "Old Story", categoryRawValue: "world", relevance: 10, date: referenceDate.addingTimeInterval(-86_401))

        #expect(StoryCollectionBuilder.buildBriefingCollection(news: [], referenceDate: referenceDate) == nil)
        #expect(StoryCollectionBuilder.buildBriefingCollection(news: [oldStory], referenceDate: referenceDate) == nil)
    }
}

private func makeStoryCollectionNews(
    id: String,
    title: String,
    categoryRawValue: String,
    relevance: Int,
    date: Date
) -> NeutralNews {
    NeutralNews(
        id: id,
        neutralTitle: title,
        neutralDescription: "\(title) description",
        category: categoryRawValue,
        relevance: relevance,
        imageUrl: "https://example.com/\(id).jpg",
        imageMedium: "Example",
        date: date,
        createdAt: date,
        updatedAt: date,
        group: 1,
        sourceIds: ["source-1", "source-2"]
    )
}
