//
//  SavedNewsServiceTests.swift
//  NeutralNewsTests
//

import Foundation
import SwiftData
import Testing
@testable import NeutralNews

@Suite("Saved News Service Tests", .serialized)
struct SavedNewsServiceTests {
    @Test("isNewsSaved detects active region item")
    func isNewsSavedDetectsActiveRegionItem() throws {
        UserDefaults.standard.set(ContentRegionPreference.us.rawValue, forKey: ContentRegionPreference.storageKey)
        let container = try makeContainer()
        SavedNewsService.shared.configure(modelContainer: container)
        defer { resetService() }

        try SavedNewsService.shared.saveNews(makeNeutralNews(id: "active-news"), regionRaw: ContentRegion.us.rawValue, relatedNews: [])

        #expect(SavedNewsService.shared.isNewsSaved(newsId: "active-news", regionRaw: ContentRegion.us.rawValue))
    }

    @Test("isNewsSaved detects legacy item")
    func isNewsSavedDetectsLegacyItem() throws {
        UserDefaults.standard.set(ContentRegionPreference.us.rawValue, forKey: ContentRegionPreference.storageKey)
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(SavedNewsItem(from: makeNeutralNews(id: "legacy-news"), relatedNews: [], regionRaw: SavedNewsRegionScope.legacy.rawValue))
        try context.save()
        SavedNewsService.shared.configure(modelContainer: container)
        defer { resetService() }

        #expect(SavedNewsService.shared.isNewsSaved(newsId: "legacy-news", regionRaw: ContentRegion.us.rawValue))
    }

    @Test("unsaveNews removes active and legacy items")
    func unsaveNewsRemovesActiveAndLegacyItems() throws {
        UserDefaults.standard.set(ContentRegionPreference.us.rawValue, forKey: ContentRegionPreference.storageKey)
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(SavedNewsItem(from: makeNeutralNews(id: "same-news"), relatedNews: [], regionRaw: ContentRegion.us.rawValue))
        context.insert(SavedNewsItem(from: makeNeutralNews(id: "same-news"), relatedNews: [], regionRaw: SavedNewsRegionScope.legacy.rawValue))
        try context.save()
        SavedNewsService.shared.configure(modelContainer: container)
        defer { resetService() }

        try SavedNewsService.shared.unsaveNews(newsId: "same-news")

        let remainingItems = try ModelContext(container).fetch(FetchDescriptor<SavedNewsItem>())
        #expect(remainingItems.isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let versionedSchema = Schema(versionedSchema: SavedNewsSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: Schema([SavedNewsItem.self]),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: versionedSchema,
            migrationPlan: SavedNewsMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func resetService() {
        UserDefaults.standard.removeObject(forKey: ContentRegionPreference.storageKey)
        SavedNewsService.shared.invalidatePreparedStore()
    }

    private func makeNeutralNews(id: String) -> NeutralNews {
        NeutralNews(
            id: id,
            neutralTitle: "Title \(id)",
            neutralDescription: "Description \(id)",
            category: "politics",
            relevance: 80,
            imageUrl: "https://example.com/image.jpg",
            imageMedium: "Example",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_200),
            group: 1,
            sourceIds: ["source-\(id)"]
        )
    }
}
