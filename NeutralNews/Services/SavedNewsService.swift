//
//  SavedNewsService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/20/25.
//

import Foundation
import SwiftData

// MARK: - Service
@MainActor
final class SavedNewsService {
    struct SavedNeutralNewsEntry {
        let neutralNews: NeutralNews
        let relatedNews: [News]
        let regionRaw: String
        let createdAt: Date
    }

    static let shared = SavedNewsService()
    private let regionProvider: ContentRegionProviding

    private var modelContainer: ModelContainer?
    private let preparationLock = NSLock()
    private var hasPreparedStore = false

    private static func makeModelContainer() throws -> ModelContainer {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let cloudStoreURL = URL.documentsDirectory.appending(path: "SavedNews.store")
        let versionedSchema = Schema(versionedSchema: SavedNewsSchemaV1.self)

        if isRunningTests {
            let configuration = ModelConfiguration(
                schema: Schema([SavedNewsItem.self]),
                url: URL.documentsDirectory.appending(path: "SavedNewsTests.store"),
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: versionedSchema,
                migrationPlan: SavedNewsMigrationPlan.self,
                configurations: [configuration]
            )
        }

        let cloudConfiguration = ModelConfiguration(
            schema: Schema([SavedNewsItem.self]),
            url: cloudStoreURL,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(
                for: versionedSchema,
                migrationPlan: SavedNewsMigrationPlan.self,
                configurations: [cloudConfiguration]
            )
        } catch let error {
            print("⚠️ SavedNews CloudKit container failed: \(error)")
            throw error
        }
    }

    private init(regionProvider: ContentRegionProviding = ContentRegionProvider()) {
        self.regionProvider = regionProvider
        self.modelContainer = nil
    }

    func configure(modelContainer: ModelContainer) {
        preparationLock.lock()
        self.modelContainer = modelContainer
        self.hasPreparedStore = false
        preparationLock.unlock()
    }

    func prewarmStore() {
        let didPrepareStore = createContext() != nil
        preparationLock.lock()
        hasPreparedStore = didPrepareStore
        preparationLock.unlock()
    }

    func invalidatePreparedStore() {
        preparationLock.lock()
        hasPreparedStore = false
        modelContainer = nil
        preparationLock.unlock()
    }

    private func createContext() -> ModelContext? {
        preparationLock.lock()
        if modelContainer == nil {
            do {
                modelContainer = try Self.makeModelContainer()
            } catch {
                preparationLock.unlock()
                print("⚠️ SavedNews SwiftData container unavailable: \(error)")
                return nil
            }
        }
        let container = modelContainer!
        preparationLock.unlock()
        return ModelContext(container)
    }

    private func currentRegionRaw() -> String {
        regionProvider.currentRegion.rawValue
    }

    private func legacyRegionRaw() -> String {
        SavedNewsRegionScope.legacy.rawValue
    }

    private func prepareStoreIfNeeded() {
        preparationLock.lock()
        if hasPreparedStore {
            preparationLock.unlock()
            return
        }
        preparationLock.unlock()

        let didPrepareStore = createContext() != nil

        preparationLock.lock()
        hasPreparedStore = didPrepareStore
        preparationLock.unlock()
    }

    private func fetchSwiftItem(storageKey: String, context: ModelContext) throws -> SavedNewsItem? {
        let descriptor = FetchDescriptor<SavedNewsItem>(
            predicate: #Predicate<SavedNewsItem> { item in
                item.storageKey == storageKey
            }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchSwiftDataSavedNeutralNewsEntries(context: ModelContext) throws -> [SavedNeutralNewsEntry] {
        let neutralNewsType = SavedNewsType.neutralNews.rawValue
        let descriptor = FetchDescriptor<SavedNewsItem>(
            predicate: #Predicate<SavedNewsItem> { item in
                item.newsType == neutralNewsType
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return try context.fetch(descriptor)
            .map { item in
                SavedNeutralNewsEntry(
                    neutralNews: item.toNeutralNews(),
                    relatedNews: item.savedRelatedNews(),
                    regionRaw: item.regionRaw,
                    createdAt: item.createdAt
                )
            }
    }

    func prepareSavedNewsStore() {
        prepareStoreIfNeeded()
    }

    func saveNews(
        _ news: Any,
        regionRaw: String? = nil,
        relatedNews: [News]? = nil
    ) throws {
        prepareStoreIfNeeded()
#if DEBUG
        print("🔄 SavedNewsService.saveNews called")
#endif

        let newsId: String

        if let neutralNews = news as? NeutralNews {
#if DEBUG
            print("📰 Preparing to save NeutralNews: \(neutralNews.id)")
#endif
            newsId = neutralNews.id
        } else if let regularNews = news as? News {
#if DEBUG
            print("📰 Preparing to save News: \(regularNews.id)")
#endif
            newsId = regularNews.id
        } else {
            print("❌ Invalid news type: \(type(of: news))")
            throw SavedNewsError.invalidNewsType
        }

        let activeRegionRaw = regionRaw ?? currentRegionRaw()
        let activeStorageKey = SavedNewsItem.storageKey(newsId: newsId, regionRaw: activeRegionRaw)
        let legacyStorageKey = SavedNewsItem.storageKey(newsId: newsId, regionRaw: legacyRegionRaw())
        guard let modelContext = createContext() else {
            throw SavedNewsError.saveFailure
        }

        let hasActiveSavedItem = try fetchSwiftItem(storageKey: activeStorageKey, context: modelContext) != nil
        let hasLegacySavedItem = try fetchSwiftItem(storageKey: legacyStorageKey, context: modelContext) != nil
        if hasActiveSavedItem || hasLegacySavedItem {
#if DEBUG
            print("⚠️ News already saved: \(newsId)")
#endif
            return // Already saved, no need to save again
        }

#if DEBUG
        print("✅ News not found in saved list, proceeding to save: \(newsId)")
#endif

        // Create the object ONLY if not already saved
        if let neutralNews = news as? NeutralNews {
            let resolvedRelatedNews = relatedNews ?? NewsDataManager.shared.getRelatedNews(from: neutralNews)
            modelContext.insert(
                SavedNewsItem(
                    from: neutralNews,
                    relatedNews: resolvedRelatedNews,
                    regionRaw: activeRegionRaw
                )
            )
#if DEBUG
            print("📰 Created SavedNews from NeutralNews: \(neutralNews.id)")
#endif
        } else if let regularNews = news as? News {
            modelContext.insert(SavedNewsItem(from: regularNews, regionRaw: activeRegionRaw))
#if DEBUG
            print("📰 Created SavedNews from News: \(regularNews.id)")
#endif
        } else {
            throw SavedNewsError.invalidNewsType
        }

#if DEBUG
        print("💾 Saving SwiftData context...")
#endif
        try modelContext.save()
#if DEBUG
        print("✅ SwiftData context saved successfully")
#endif

        SavedNewsState.shared.setSaved(true, for: newsId, regionRaw: activeRegionRaw)

        // Track positive interaction for rating
        RatingManager.shared.incrementSavedNewsCount()
        RatingManager.shared.requestRatingAfterPositiveInteraction()
    }

    func unsaveNews(newsId: String, regionRaw: String? = nil) throws {
        prepareStoreIfNeeded()

        let targetRegionRaw = regionRaw ?? currentRegionRaw()
        let activeStorageKey = SavedNewsItem.storageKey(newsId: newsId, regionRaw: targetRegionRaw)
        let legacyStorageKey = SavedNewsItem.storageKey(newsId: newsId, regionRaw: legacyRegionRaw())
        guard let modelContext = createContext() else {
            throw SavedNewsError.saveFailure
        }

        if let savedItem = try fetchSwiftItem(storageKey: activeStorageKey, context: modelContext) {
            modelContext.delete(savedItem)
        }
        if regionRaw == nil, let legacyItem = try fetchSwiftItem(storageKey: legacyStorageKey, context: modelContext) {
            modelContext.delete(legacyItem)
        }
        try modelContext.save()

        let shouldClearLegacyState = regionRaw == nil
        SavedNewsState.shared.setSaved(false, for: newsId, regionRaw: targetRegionRaw)
        if shouldClearLegacyState {
            SavedNewsState.shared.setSaved(false, for: newsId, regionRaw: SavedNewsRegionScope.legacy.rawValue)
        }
    }

    func isNewsSaved(newsId: String, regionRaw: String? = nil) -> Bool {
        prepareStoreIfNeeded()

        let activeRegionRaw = regionRaw ?? currentRegionRaw()
        let activeStorageKey = SavedNewsItem.storageKey(newsId: newsId, regionRaw: activeRegionRaw)
        let legacyStorageKey = SavedNewsItem.storageKey(newsId: newsId, regionRaw: legacyRegionRaw())
        let modelContext = createContext()

        do {
            if let modelContext {
                if try fetchSwiftItem(storageKey: activeStorageKey, context: modelContext) != nil {
                    return true
                }
                if try fetchSwiftItem(storageKey: legacyStorageKey, context: modelContext) != nil {
                    return true
                }
            }
        } catch {
            print("❌ Error checking SwiftData saved news status: \(error)")
        }

        return false
    }

    func getSavedNeutralNews() throws -> [SavedNeutralNewsEntry] {
        prepareStoreIfNeeded()

        let modelContext = createContext()

        guard let modelContext else {
            throw SavedNewsError.fetchFailure
        }

        return try fetchSwiftDataSavedNeutralNewsEntries(context: modelContext)
    }
}

enum SavedNewsError: Error {
    case invalidNewsType
    case saveFailure
    case fetchFailure
}
