//
//  CacheServiceTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import Testing
@testable import NeutralNews

@Suite("CacheService Tests")
struct CacheServiceTests {
    private let cacheService = CacheService.shared

    @Test("Unknown day has no valid cache entries")
    func unknownDayHasNoValidCacheEntries() {
        let day = makeDay(daysFromNow: -45)

        #expect(cacheService.isCacheValid(for: day) == false)
        #expect(cacheService.getCachedNeutralNews(for: day).isEmpty == true)
        #expect(cacheService.getCachedNews(for: day).isEmpty == true)
    }

    @Test("Caching neutral news replaces previous entries for the same day")
    func cachingNeutralNewsReplacesPreviousEntriesForTheSameDay() {
        let day = makeDay(daysFromNow: -46)
        let firstBatch = [
            makeNeutralNews(id: "cache-neutral-old", title: "Old cached story", date: day.date)
        ]
        let replacementBatch = [
            makeNeutralNews(id: "cache-neutral-newer", title: "Newer story", date: day.date.addingTimeInterval(7_200)),
            makeNeutralNews(id: "cache-neutral-older", title: "Older story", date: day.date.addingTimeInterval(3_600))
        ]

        cacheService.cacheNeutralNews(firstBatch, for: day)
        cacheService.cacheNeutralNews(replacementBatch, for: day)

        let cached = cacheService.getCachedNeutralNews(for: day)

        #expect(cached.map(\.id) == ["cache-neutral-newer", "cache-neutral-older"])
        #expect(cached.contains { $0.id == "cache-neutral-old" } == false)
    }

    @Test("Caching regular news returns entries sorted by publication date")
    func cachingRegularNewsReturnsEntriesSortedByPublicationDate() {
        let day = makeDay(daysFromNow: -47)
        let older = makeNews(id: "cache-news-older", title: "Older source", pubDate: day.date)
        let newer = makeNews(id: "cache-news-newer", title: "Newer source", pubDate: day.date.addingTimeInterval(7_200))

        cacheService.cacheNews([older, newer], for: day)

        let cached = cacheService.getCachedNews(for: day)

        #expect(cached.map(\.id) == [newer.id, older.id])
        #expect(cached.first?.publisher == "Example Publisher")
    }

    @Test("Neutral and regular news cache validity are checked independently")
    func neutralAndRegularNewsCacheValidityAreCheckedIndependently() {
        let day = makeDay(daysFromNow: 49)
        let neutral = makeNeutralNews(id: "cache-validity-neutral", title: "Neutral only", date: day.date)

        cacheService.cacheNeutralNews([neutral], for: day)

        #expect(cacheService.isNeutralNewsCacheValid(for: day) == true)
        #expect(cacheService.isNewsCacheValid(for: day) == false)
    }

    @Test("Caching an empty neutral news batch preserves the existing cache")
    func cachingAnEmptyNeutralNewsBatchPreservesTheExistingCache() {
        let day = makeDay(daysFromNow: -48)
        let existing = makeNeutralNews(id: "cache-neutral-existing", title: "Existing story", date: day.date)

        cacheService.cacheNeutralNews([existing], for: day)
        cacheService.cacheNeutralNews([], for: day)

        #expect(cacheService.getCachedNeutralNews(for: day).map(\.id) == [existing.id])
    }

    @Test("Expired cache cleanup removes entries older than seven days and keeps recent ones")
    func expiredCacheCleanupRemovesOldEntriesAndKeepsRecentOnes() async {
        let oldDay = makeDay(daysFromNow: -15)
        let recentDay = makeDay(daysFromNow: -1)
        let oldNeutral = makeNeutralNews(id: "cache-cleanup-old-neutral", title: "Old neutral", date: oldDay.date)
        let oldRegular = makeNews(id: "cache-cleanup-old-news", title: "Old source", pubDate: oldDay.date)
        let recentNeutral = makeNeutralNews(id: "cache-cleanup-recent-neutral", title: "Recent neutral", date: recentDay.date)
        let recentRegular = makeNews(id: "cache-cleanup-recent-news", title: "Recent source", pubDate: recentDay.date)

        cacheService.cacheNeutralNews([oldNeutral], for: oldDay)
        cacheService.cacheNews([oldRegular], for: oldDay)
        cacheService.cacheNeutralNews([recentNeutral], for: recentDay)
        cacheService.cacheNews([recentRegular], for: recentDay)

        await cacheService.cleanExpiredCache()

        #expect(cacheService.getCachedNeutralNews(for: oldDay).contains { $0.id == oldNeutral.id } == false)
        #expect(cacheService.getCachedNews(for: oldDay).contains { $0.id == oldRegular.id } == false)
        #expect(cacheService.getCachedNeutralNews(for: recentDay).contains { $0.id == recentNeutral.id })
        #expect(cacheService.getCachedNews(for: recentDay).contains { $0.id == recentRegular.id })
    }

    private func makeDay(daysFromNow: Int) -> DayInfo {
        let date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        return DayInfo(date: date)
    }

    private func makeNeutralNews(id: String, title: String, date: Date) -> NeutralNews {
        NeutralNews(
            id: id,
            neutralTitle: title,
            neutralDescription: "\(title) summary",
            category: Category.business.rawValue,
            relevance: 5,
            imageUrl: "https://example.com/\(id).jpg",
            imageMedium: "Example",
            date: date,
            createdAt: date,
            updatedAt: date,
            group: 1,
            sourceIds: ["\(id)-source-a", "\(id)-source-b"]
        )
    }

    private func makeNews(id: String, title: String, pubDate: Date) -> News {
        News(
            id: id,
            title: title,
            description: "\(title) description",
            scrappedDescription: nil,
            category: Category.business.rawValue,
            imageUrl: "https://example.com/\(id).jpg",
            link: "https://example.com/\(id)",
            pubDate: pubDate,
            createdAt: pubDate,
            updatedAt: pubDate,
            publisher: "Example Publisher",
            neutralScore: 55,
            group: 1,
            embedding: [0.3, 0.7]
        )
    }
}
