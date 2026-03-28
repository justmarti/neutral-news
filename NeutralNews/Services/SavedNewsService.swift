//
//  SavedNewsService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/20/25.
//

import Foundation
import CoreData
import SwiftData

// MARK: - Service
final class SavedNewsService {
    struct SavedNeutralNewsEntry {
        let neutralNews: NeutralNews
        let relatedNews: [News]
        let regionRaw: String
        let createdAt: Date
    }

    static let shared = SavedNewsService()
    private let newsDataManager = NewsDataManager.shared
    private let regionProvider: ContentRegionProviding

    private var modelContainer: ModelContainer?
    private let preparationLock = NSLock()
    private let migrationLock = NSLock()
    private var hasPreparedStore = false
    private var isPreparingStore = false
    private let migrationBatchSize = 20

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
        _ = createContext()
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

    private func prepareStoreIfNeeded(coreDataContext: NSManagedObjectContext?) {
        preparationLock.lock()
        if hasPreparedStore || isPreparingStore {
            preparationLock.unlock()
            return
        }
        isPreparingStore = true
        preparationLock.unlock()

        let didPrepareStore = migrateCoreDataSavedNewsIfNeeded(coreDataContext: coreDataContext)

        preparationLock.lock()
        hasPreparedStore = didPrepareStore
        isPreparingStore = false
        preparationLock.unlock()
    }

    private func migrateCoreDataSavedNewsIfNeeded(coreDataContext: NSManagedObjectContext?) -> Bool {
        migrationLock.lock()
        defer { migrationLock.unlock() }

        let sourceContext = coreDataContext ?? CoreDataManager.shared.viewContext
        let coreDataItems = fetchCoreDataSavedNews(context: sourceContext)
        guard !coreDataItems.isEmpty else { return true }

        guard let context = createContext() else { return false }

        do {
            let existingItems = try context.fetch(FetchDescriptor<SavedNewsItem>())
            var existingStorageKeys = Set(existingItems.map(\.storageKey))
            var insertedCount = 0

            for coreDataItem in coreDataItems {
                guard coreDataItem.newsType == SavedNewsType.neutralNews.rawValue else {
                    continue
                }

                guard let neutralNews = coreDataItem.toNeutralNews() else {
                    continue
                }

                let storageKey = SavedNewsItem.storageKey(
                    newsId: neutralNews.id,
                    regionRaw: legacyRegionRaw()
                )
                guard !existingStorageKeys.contains(storageKey) else {
                    continue
                }

                let migratedItem = SavedNewsItem(
                    from: neutralNews,
                    relatedNews: coreDataItem.savedRelatedNews(),
                    regionRaw: legacyRegionRaw(),
                    createdAt: coreDataItem.createdAt ?? Date()
                )
                context.insert(migratedItem)
                existingStorageKeys.insert(storageKey)
                insertedCount += 1

                if insertedCount.isMultiple(of: migrationBatchSize) {
                    try context.save()
                }
            }

            if context.hasChanges {
                try context.save()
            }

#if DEBUG
            print("✅ Core Data -> SwiftData migration completed. Inserted: \(insertedCount)")
#endif
            return true
        } catch {
            print("❌ Failed to migrate saved news to SwiftData: \(error)")
            return false
        }
    }

    private func fetchCoreDataSavedNews(context: NSManagedObjectContext) -> [SavedNews] {
        var results: [SavedNews] = []
        context.performAndWait {
            let fetchRequest: NSFetchRequest<SavedNews> = SavedNews.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            results = (try? context.fetch(fetchRequest)) ?? []
        }
        return results
    }

    private func isCoreDataNewsSaved(newsId: String, context: NSManagedObjectContext?) -> Bool {
        guard let context else { return false }

        var found = false
        context.performAndWait {
            let fetchRequest: NSFetchRequest<SavedNews> = SavedNews.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "newsId == %@", newsId)
            let results = try? context.fetch(fetchRequest)
            found = (results?.isEmpty == false)
        }
        return found
    }

    private func deleteCoreDataSavedNews(newsId: String, context: NSManagedObjectContext?) {
        guard let context else { return }

        context.performAndWait {
            let fetchRequest: NSFetchRequest<SavedNews> = SavedNews.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "newsId == %@", newsId)

            guard let results = try? context.fetch(fetchRequest), !results.isEmpty else {
                return
            }

            for item in results {
                context.delete(item)
            }
            try? context.save()
        }
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
        let descriptor = FetchDescriptor<SavedNewsItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return try context.fetch(descriptor)
            .filter { $0.newsType == SavedNewsType.neutralNews.rawValue }
            .map { item in
                SavedNeutralNewsEntry(
                    neutralNews: item.toNeutralNews(),
                    relatedNews: item.savedRelatedNews(),
                    regionRaw: item.regionRaw,
                    createdAt: item.createdAt
                )
            }
    }

    private func fetchCoreDataSavedNeutralNewsEntries(context: NSManagedObjectContext) -> [SavedNeutralNewsEntry] {
        fetchCoreDataSavedNews(context: context).compactMap { coreDataItem in
            guard coreDataItem.newsType == SavedNewsType.neutralNews.rawValue,
                  let neutralNews = coreDataItem.toNeutralNews() else {
                return nil
            }

            return SavedNeutralNewsEntry(
                neutralNews: neutralNews,
                relatedNews: coreDataItem.savedRelatedNews(),
                regionRaw: legacyRegionRaw(),
                createdAt: coreDataItem.createdAt ?? Date.distantPast
            )
        }
    }

    static func mergeSavedNeutralNewsEntries(
        primary: [SavedNeutralNewsEntry],
        fallback: [SavedNeutralNewsEntry]
    ) -> [SavedNeutralNewsEntry] {
        var mergedByStorageKey: [String: SavedNeutralNewsEntry] = [:]

        for entry in primary {
            let storageKey = SavedNewsItem.storageKey(
                newsId: entry.neutralNews.id,
                regionRaw: entry.regionRaw
            )
            mergedByStorageKey[storageKey] = entry
        }

        for entry in fallback {
            let storageKey = SavedNewsItem.storageKey(
                newsId: entry.neutralNews.id,
                regionRaw: entry.regionRaw
            )
            if mergedByStorageKey[storageKey] == nil {
                mergedByStorageKey[storageKey] = entry
            }
        }

        return mergedByStorageKey.values.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    func prepareSavedNewsStore(coreDataContext: NSManagedObjectContext? = nil) {
        prepareStoreIfNeeded(coreDataContext: coreDataContext)
    }

    func saveNews(
        _ news: Any,
        context: NSManagedObjectContext? = nil,
        regionRaw: String? = nil,
        relatedNews: [News]? = nil
    ) throws {
        prepareStoreIfNeeded(coreDataContext: context)
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
        let modelContext = createContext()

        let hasActiveSavedItem = try modelContext.map { try fetchSwiftItem(storageKey: activeStorageKey, context: $0) != nil } ?? false
        let hasLegacySavedItem = try modelContext.map { try fetchSwiftItem(storageKey: legacyStorageKey, context: $0) != nil } ?? false
        let hasLegacyCoreDataItem = isCoreDataNewsSaved(newsId: newsId, context: context)
        if hasActiveSavedItem || hasLegacySavedItem || hasLegacyCoreDataItem {
#if DEBUG
            print("⚠️ News already saved: \(newsId)")
#endif
            return // Already saved, no need to save again
        }

#if DEBUG
        print("✅ News not found in saved list, proceeding to save: \(newsId)")
#endif

        if let modelContext {
            // Create the object ONLY if not already saved
            if let neutralNews = news as? NeutralNews {
                let resolvedRelatedNews = relatedNews ?? newsDataManager.getRelatedNews(from: neutralNews)
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
        } else {
            throw SavedNewsError.saveFailure
        }
        Task { @MainActor in
            SavedNewsState.shared.setSaved(true, for: newsId, regionRaw: activeRegionRaw)
        }

        // Track positive interaction for rating
        Task { @MainActor in
            RatingManager.shared.incrementSavedNewsCount()
            RatingManager.shared.requestRatingAfterPositiveInteraction()
        }
    }

    func unsaveNews(newsId: String, context: NSManagedObjectContext? = nil, regionRaw: String? = nil) throws {
        prepareStoreIfNeeded(coreDataContext: context)

        let targetRegionRaw = regionRaw ?? currentRegionRaw()
        let activeStorageKey = SavedNewsItem.storageKey(newsId: newsId, regionRaw: targetRegionRaw)
        let legacyStorageKey = SavedNewsItem.storageKey(newsId: newsId, regionRaw: legacyRegionRaw())
        let modelContext = createContext()

        if let modelContext {
            if let savedItem = try fetchSwiftItem(storageKey: activeStorageKey, context: modelContext) {
                modelContext.delete(savedItem)
            }
            if let legacyItem = try fetchSwiftItem(storageKey: legacyStorageKey, context: modelContext) {
                modelContext.delete(legacyItem)
            }
            if modelContext.hasChanges {
                try modelContext.save()
            }
        }

        // TODO(migration): Remove Core Data delete sync after one stable release with
        // no saved-news migration incidents in Crashlytics.
        // Keep legacy Core Data in sync during migration window.
        deleteCoreDataSavedNews(newsId: newsId, context: context)

        Task { @MainActor in
            SavedNewsState.shared.setSaved(false, for: newsId, regionRaw: targetRegionRaw)
        }
    }

    func isNewsSaved(newsId: String, context: NSManagedObjectContext? = nil, regionRaw: String? = nil) -> Bool {
        prepareStoreIfNeeded(coreDataContext: context)

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

        // TODO(migration): Remove Core Data fallback after one stable release with
        // no saved-news migration incidents in Crashlytics.
        // Temporary fallback to avoid regressions during migration.
        return isCoreDataNewsSaved(newsId: newsId, context: context)
    }

    func getSavedNeutralNews(context: NSManagedObjectContext?) throws -> [SavedNeutralNewsEntry] {
        prepareStoreIfNeeded(coreDataContext: context)
        migrateCoreDataSavedNewsIfNeeded(coreDataContext: context)

        let modelContext = createContext()
        let swiftDataEntries: [SavedNeutralNewsEntry]

        if let modelContext {
            do {
                swiftDataEntries = try fetchSwiftDataSavedNeutralNewsEntries(context: modelContext)
            } catch {
                print("❌ Failed to fetch SwiftData saved news. Falling back to Core Data merge: \(error)")
                swiftDataEntries = []
            }
        } else {
            swiftDataEntries = []
        }

        guard let context else { return swiftDataEntries }

        let coreDataEntries = fetchCoreDataSavedNeutralNewsEntries(context: context)
        return Self.mergeSavedNeutralNewsEntries(
            primary: swiftDataEntries,
            fallback: coreDataEntries
        )
    }

    func getSavedNews(context: NSManagedObjectContext) throws -> [SavedNews] {
        let fetchRequest: NSFetchRequest<SavedNews> = SavedNews.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        return try context.fetch(fetchRequest)
    }
}

enum SavedNewsError: Error {
    case invalidNewsType
    case saveFailure
    case fetchFailure
}
