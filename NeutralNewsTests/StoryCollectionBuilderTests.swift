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
    @Test("Builds the briefing from the top six stories by relevance")
    func buildsBriefingFromTopSixStoriesByRelevance() {
        let date = Date()
        let world1 = makeStoryCollectionNews(id: "world-1", title: "World 1", categoryRawValue: "world", relevance: 8, date: date)
        let world2 = makeStoryCollectionNews(id: "world-2", title: "World 2", categoryRawValue: "world", relevance: 4, date: date.addingTimeInterval(60))
        let world3 = makeStoryCollectionNews(id: "world-3", title: "World 3", categoryRawValue: "world", relevance: 7, date: date.addingTimeInterval(120))
        let politics1 = makeStoryCollectionNews(id: "politics-1", title: "Politics 1", categoryRawValue: "politics", relevance: 9, date: date.addingTimeInterval(180))
        let politics2 = makeStoryCollectionNews(id: "politics-2", title: "Politics 2", categoryRawValue: "politics", relevance: 5, date: date.addingTimeInterval(240))
        let tech1 = makeStoryCollectionNews(id: "tech-1", title: "Tech 1", categoryRawValue: "technology", relevance: 6, date: date.addingTimeInterval(300))
        let business1 = makeStoryCollectionNews(id: "business-1", title: "Business 1", categoryRawValue: "business", relevance: 3, date: date.addingTimeInterval(360))

        let dayNews = [world1, world2, world3, politics1, politics2, tech1, business1]

        let briefingCollection = StoryCollectionBuilder.buildBriefingCollection(dayNews: dayNews)

        #expect(briefingCollection?.coverNews.id == "politics-1")
        #expect(briefingCollection?.items.map(\.id) == [
            "politics-1",
            "world-1",
            "world-3",
            "tech-1",
            "politics-2",
            "world-2"
        ])
    }

    @Test("Returns nil when there are no stories")
    func returnsNilWhenThereAreNoStories() {
        #expect(StoryCollectionBuilder.buildBriefingCollection(dayNews: []) == nil)
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
        sourceIds: ["source-1", "source-2"],
        storyFocusPoint: nil
    )
}
