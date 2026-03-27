//
//  ViewModelTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import Testing
@testable import NeutralNews

@MainActor
@Suite("News Filter View Model Tests")
struct NewsFilterViewModelTests {

    @Test("Day-selected scope only returns stories from the selected date")
    func daySelectedScopeOnlyReturnsStoriesFromTheSelectedDate() {
        let sut = NewsFilterViewModel()
        let selectedDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let selectedDay = DayInfo(date: selectedDate)
        let laterStory = makeNeutralNews(
            id: "filter-day-later",
            title: "Later story",
            date: selectedDate.addingTimeInterval(7_200)
        )
        let earlierStory = makeNeutralNews(
            id: "filter-day-earlier",
            title: "Earlier story",
            date: selectedDate.addingTimeInterval(1_800)
        )
        let otherDayStory = makeNeutralNews(
            id: "filter-day-other",
            title: "Other day story",
            date: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        )

        let filtered = sut.applyFilters(to: [earlierStory, otherDayStory, laterStory], daySelected: selectedDay)

        #expect(filtered.map(\.id) == [laterStory.id, earlierStory.id])
    }

    @Test("Search normalizes accents and prioritizes title matches over description matches")
    func searchNormalizesAccentsAndPrioritizesTitleMatches() throws {
        let sut = NewsFilterViewModel()
        let titleMatch = makeNeutralNews(
            id: "filter-search-title",
            title: "Política española",
            description: "Coverage summary",
            date: Date()
        )
        let descriptionMatch = makeNeutralNews(
            id: "filter-search-description",
            title: "Economic briefing",
            description: "Análisis de política comparada",
            date: Date().addingTimeInterval(7_200)
        )

        sut.searchText = "politica"

        let filtered = sut.applyFilters(to: [descriptionMatch, titleMatch])
        let first = try #require(filtered.first)

        #expect(filtered.map(\.id) == [titleMatch.id, descriptionMatch.id])
        #expect(first.id == titleMatch.id)
    }

    @Test("Category filter accepts legacy backend aliases")
    func categoryFilterAcceptsLegacyBackendAliases() {
        let sut = NewsFilterViewModel()
        let politics = makeNeutralNews(id: "filter-category-politics", title: "Politics", category: "politica")
        let business = makeNeutralNews(id: "filter-category-business", title: "Business", category: "business")

        sut.categoryFilter = [.politics]

        let filtered = sut.applyFilters(to: [politics, business])

        #expect(filtered.map(\.id) == [politics.id])
    }

    @Test("Relevance order sorts highest relevance stories first")
    func relevanceOrderSortsHighestRelevanceFirst() {
        let sut = NewsFilterViewModel()
        let low = makeNeutralNews(id: "filter-relevance-low", title: "Low", relevance: 2)
        let high = makeNeutralNews(id: "filter-relevance-high", title: "High", relevance: 9)
        let medium = makeNeutralNews(id: "filter-relevance-medium", title: "Medium", relevance: 5)

        sut.orderBy = .relevance

        let filtered = sut.applyFilters(to: [medium, low, high])

        #expect(filtered.map(\.id) == [high.id, medium.id, low.id])
    }

    @Test("Popularity order sorts stories with more linked sources first")
    func popularityOrderSortsStoriesWithMoreLinkedSourcesFirst() {
        let sut = NewsFilterViewModel()
        let lowCoverage = makeNeutralNews(
            id: "filter-popularity-low",
            title: "Low coverage",
            sourceIds: ["source-1"]
        )
        let highCoverage = makeNeutralNews(
            id: "filter-popularity-high",
            title: "High coverage",
            sourceIds: ["source-1", "source-2", "source-3"]
        )

        sut.orderBy = .popularity

        let filtered = sut.applyFilters(to: [lowCoverage, highCoverage])

        #expect(filtered.map(\.id) == [highCoverage.id, lowCoverage.id])
    }
}

@MainActor
@Suite("News List View Model Tests")
struct NewsListViewModelTests {
    private let manager = NewsDataManager.shared
    private let cacheService = CacheService.shared

    @Test("Related news falls back to saved snapshots when live sources are missing")
    func relatedNewsFallsBackToSavedSnapshotsWhenLiveSourcesAreMissing() {
        let viewModel = NewsListViewModel.shared
        let neutralNewsId = "saved-\(UUID().uuidString)"
        let savedRelatedNews = makeNews(id: "saved-source-\(UUID().uuidString)", title: "Saved related source")
        let neutralNews = makeNeutralNews(id: neutralNewsId, title: "Saved article", sourceIds: [])

        let previousIsShowingSavedNews = viewModel.isShowingSavedNews
        let previousSavedRelatedNews = viewModel.savedRelatedNewsByNeutralId

        defer {
            viewModel.savedRelatedNewsByNeutralId = previousSavedRelatedNews
            viewModel.isShowingSavedNews = previousIsShowingSavedNews
        }

        viewModel.savedRelatedNewsByNeutralId = [neutralNewsId: [savedRelatedNews]]
        viewModel.isShowingSavedNews = true

        #expect(viewModel.getRelatedNews(from: neutralNews) == [savedRelatedNews])
    }

    @Test("Visible categories come from the selected day dataset")
    func visibleCategoriesComeFromTheSelectedDayDataset() async {
        let viewModel = NewsListViewModel.shared
        let day = DayInfo(date: Calendar.current.date(byAdding: .day, value: 33, to: Date())!)
        let politicsStory = makeNeutralNews(
            id: "viewmodel-categories-politics",
            title: "Politics",
            category: "politica",
            date: day.date
        )
        let businessStory = makeNeutralNews(
            id: "viewmodel-categories-business",
            title: "Business",
            category: "business",
            date: day.date.addingTimeInterval(1_800)
        )

        let previousDaySelected = viewModel.daySelected
        let previousIsShowingAllDays = viewModel.isShowingAllDays
        let previousIsShowingSavedNews = viewModel.isShowingSavedNews
        let previousSearchScope = viewModel.searchScope

        defer {
            viewModel.daySelected = previousDaySelected
            viewModel.isShowingAllDays = previousIsShowingAllDays
            viewModel.isShowingSavedNews = previousIsShowingSavedNews
            viewModel.searchScope = previousSearchScope
        }

        cacheService.cacheNeutralNews([politicsStory, businessStory], for: day)
        await manager.loadNews(for: day)

        viewModel.isShowingSavedNews = false
        viewModel.isShowingAllDays = false
        viewModel.searchScope = .daySelected
        viewModel.daySelected = day

        #expect(viewModel.getCategoriesOfTheDay() == [.politics, .business])
    }

    @Test("Restoring saved news updates an existing item without duplicating it")
    func restoringSavedNewsUpdatesAnExistingItemWithoutDuplicatingIt() {
        let viewModel = NewsListViewModel.shared
        let newsId = "saved-restore-\(UUID().uuidString)"
        let original = makeNeutralNews(
            id: newsId,
            title: "Original title",
            date: Date().addingTimeInterval(-3_600)
        )
        let restored = makeNeutralNews(
            id: newsId,
            title: "Updated title",
            date: Date()
        )
        let related = [makeNews(id: "saved-related-\(UUID().uuidString)", title: "Related source")]

        let previousSavedNews = viewModel.savedNews
        let previousSavedRelatedNews = viewModel.savedRelatedNewsByNeutralId
        let previousSavedRegions = viewModel.savedRegionByNewsId

        defer {
            viewModel.savedNews = previousSavedNews
            viewModel.savedRelatedNewsByNeutralId = previousSavedRelatedNews
            viewModel.savedRegionByNewsId = previousSavedRegions
        }

        viewModel.savedNews = [original]
        viewModel.savedRelatedNewsByNeutralId = [:]
        viewModel.savedRegionByNewsId = [:]

        viewModel.restoreSavedNews(restored, relatedNews: related, regionRaw: ContentRegion.es.rawValue)

        #expect(viewModel.savedNews.count == 1)
        #expect(viewModel.savedNews.first?.neutralTitle == "Updated title")
        #expect(viewModel.savedRelatedNewsByNeutralId[newsId] == related)
        #expect(viewModel.savedRegionByNewsId[newsId] == ContentRegion.es.rawValue)
    }
}

private func makeNeutralNews(
    id: String,
    title: String,
    description: String = "Test description",
    category: String = Category.politics.rawValue,
    relevance: Int = 5,
    date: Date = Date(),
    sourceIds: [String] = ["test-source-1", "test-source-2"]
) -> NeutralNews {
    NeutralNews(
        id: id,
        neutralTitle: title,
        neutralDescription: description,
        category: category,
        relevance: relevance,
        imageUrl: "https://example.com/\(id).jpg",
        imageMedium: "Example",
        date: date,
        createdAt: date,
        updatedAt: date,
        group: 1,
        sourceIds: sourceIds
    )
}

private func makeNews(id: String, title: String) -> News {
    let date = Date()
    return News(
        id: id,
        title: title,
        description: "\(title) description",
        scrappedDescription: "\(title) body",
        category: Category.politics.rawValue,
        imageUrl: "https://example.com/\(id).jpg",
        link: "https://example.com/\(id)",
        pubDate: date,
        createdAt: date,
        updatedAt: date,
        publisher: "Example Publisher",
        neutralScore: 50,
        group: 1,
        embedding: []
    )
}
