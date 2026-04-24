//
//  NewsDataManagerTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import Testing
@testable import NeutralNews

@Suite("NewsDataManager Tests")
struct NewsDataManagerTests {
    private let manager = NewsDataManager.shared
    private let cacheService = CacheService.shared

    @Test("Last seven days contains seven unique dates in descending order")
    func lastSevenDaysContainsSevenUniqueDescendingDates() {
        let days = manager.lastSevenDays

        #expect(days.count == 7)
        #expect(Set(days).count == 7)

        for (current, next) in zip(days, days.dropFirst()) {
            #expect(current.date > next.date)
        }
    }

    @Test("Load news uses a valid cache entry and marks the day as loaded")
    func loadNewsUsesCacheAndMarksDayAsLoaded() async {
        let day = makeDay(daysFromNow: 30)
        let newerStory = makeNeutralNews(
            id: "manager-cache-newer",
            title: "Cached newer story",
            date: day.date.addingTimeInterval(3_600)
        )
        let olderStory = makeNeutralNews(
            id: "manager-cache-older",
            title: "Cached older story",
            date: day.date
        )

        cacheService.cacheNeutralNews([olderStory, newerStory], for: day)

        #expect(cacheService.isCacheValid(for: day) == true)

        await manager.loadNews(for: day)

        #expect(manager.isDayLoaded(day) == true)
        #expect(manager.getNewsArrayForDay(day).map(\.id) == [newerStory.id, olderStory.id])
    }

    @Test("Related news resolves cached source identifiers in source order")
    func relatedNewsResolvesCachedSourceIdentifiersInSourceOrder() async {
        let day = makeDay(daysFromNow: 31)
        let sourceOne = makeNews(
            id: "manager-related-1",
            title: "Publisher one",
            pubDate: day.date.addingTimeInterval(1_800)
        )
        let sourceTwo = makeNews(
            id: "manager-related-2",
            title: "Publisher two",
            pubDate: day.date.addingTimeInterval(3_600)
        )
        let neutral = makeNeutralNews(
            id: "manager-related-neutral",
            title: "Neutral bundle",
            date: day.date,
            sourceIds: [sourceTwo.id, "manager-related-missing", sourceOne.id]
        )

        cacheService.cacheNeutralNews([neutral], for: day)
        cacheService.cacheNews([sourceOne, sourceTwo], for: day)

        await manager.loadNews(for: day)

        #expect(manager.getRelatedNews(from: neutral).map(\.id) == [sourceTwo.id, sourceOne.id])
    }

    @Test("Loading the same cached day twice does not duplicate entries")
    func loadingTheSameCachedDayTwiceDoesNotDuplicateEntries() async {
        let day = makeDay(daysFromNow: 32)
        let neutral = makeNeutralNews(
            id: "manager-dedup-neutral",
            title: "Deduplicated story",
            date: day.date,
            sourceIds: ["manager-dedup-source"]
        )
        let source = makeNews(
            id: "manager-dedup-source",
            title: "Deduplicated source",
            pubDate: day.date
        )

        cacheService.cacheNeutralNews([neutral], for: day)
        cacheService.cacheNews([source], for: day)

        await manager.loadNews(for: day)
        await manager.loadNews(for: day)

        #expect(manager.getNewsArrayForDay(day).map(\.id) == [neutral.id])
        #expect(manager.allNews.filter { $0.id == source.id }.count == 1)
    }

    private func makeDay(daysFromNow: Int) -> DayInfo {
        let date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        return DayInfo(date: date)
    }

    private func makeNeutralNews(
        id: String,
        title: String,
        date: Date,
        sourceIds: [String] = ["source-a", "source-b"]
    ) -> NeutralNews {
        NeutralNews(
            id: id,
            neutralTitle: title,
            neutralDescription: "\(title) summary",
            category: Category.technology.rawValue,
            relevance: 5,
            imageUrl: "https://example.com/\(id).jpg",
            imageMedium: "Example",
            date: date,
            createdAt: date,
            updatedAt: date,
            group: 1,
            sourceIds: sourceIds,
            storyFocusPoint: nil
        )
    }

    private func makeNews(id: String, title: String, pubDate: Date) -> News {
        News(
            id: id,
            title: title,
            description: "\(title) description",
            scrappedDescription: "\(title) body",
            category: Category.technology.rawValue,
            imageUrl: "https://example.com/\(id).jpg",
            link: "https://example.com/\(id)",
            pubDate: pubDate,
            createdAt: pubDate,
            updatedAt: pubDate,
            publisher: "Example Publisher",
            neutralScore: 50,
            group: 1,
            embedding: [0.1, 0.2]
        )
    }
}
