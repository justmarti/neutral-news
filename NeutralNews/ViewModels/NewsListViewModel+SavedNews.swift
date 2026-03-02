//
//  NewsListViewModel+SavedNews.swift
//  NeutralNews
//

import Foundation

extension NewsListViewModel {
    // MARK: - Saved News Methods

    /// Toggles between saved news view and regular news view.
    ///
    /// Automatically clears all active filters when switching modes to prevent confusion.
    ///
    /// - Note: When entering saved news mode, automatically triggers `loadSavedNews()`
    /// - Important: Premium feature - requires `PremiumManager.canSaveNews` permission
    func toggleSavedNewsMode() {
        isShowingSavedNews.toggle()
        filterViewModel.clearFilters()
    }

    /// Loads all saved news from Core Data persistent storage.
    ///
    /// Fetches saved news items from Core Data, converts them back to `NeutralNews` objects,
    /// and updates the `savedNews` array sorted by date (newest first).
    ///
    /// - Important: Requires `coreDataContext` to be set. Will fail silently if not available.
    /// - Note: This is an async operation that updates `isLoadingSavedNews` state
    func loadSavedNews() async {
        guard let context = coreDataContext else {
            print("❌ No Core Data context available")
            return
        }

#if DEBUG
        print("🔄 Loading saved news from Core Data")
#endif

        await MainActor.run {
            isLoadingSavedNews = true
        }

        defer {
            Task { @MainActor in
                isLoadingSavedNews = false
            }
        }

        do {
            let savedNewsItems = try savedNewsService.getSavedNews(context: context)
#if DEBUG
            print("📰 Found \(savedNewsItems.count) saved news items")
#endif

            let parsedSavedItems = savedNewsItems.compactMap { savedNews -> (neutral: NeutralNews, related: [News])? in
                guard savedNews.newsType == SavedNewsType.neutralNews.rawValue else {
#if DEBUG
                    print("⚠️ Skipping non-neutral news: \(savedNews.newsType ?? "unknown")")
#endif
                    return nil
                }

                guard let neutralNews = savedNews.toNeutralNews() else {
                    return nil
                }

                return (neutral: neutralNews, related: savedNews.savedRelatedNews())
            }

#if DEBUG
            print("✅ Successfully parsed \(parsedSavedItems.count) neutral news items")
#endif

            await MainActor.run {
                let sortedSavedItems = parsedSavedItems.sorted { $0.neutral.date > $1.neutral.date }
                var seenNewsIds = Set<String>()
                var deduplicatedNews: [NeutralNews] = []
                var deduplicatedRelatedNewsById: [String: [News]] = [:]

                for item in sortedSavedItems {
                    let newsId = item.neutral.id
                    guard seenNewsIds.insert(newsId).inserted else { continue }

                    deduplicatedNews.append(item.neutral)
                    deduplicatedRelatedNewsById[newsId] = item.related
                }

                savedNews = deduplicatedNews
                savedRelatedNewsByNeutralId = deduplicatedRelatedNewsById
                SavedNewsState.shared.markSaved(newsIds: savedNews.map(\.id))
#if DEBUG
                print("🎯 savedNews updated with \(savedNews.count) items")
#endif
            }

            let prefetchURLs = parsedSavedItems.map(\.neutral)
                .prefix(50)
                .compactMap { URL(string: $0.imageUrl) }

            await MainActor.run {
                savedNewsPrefetchTask?.cancel()
                savedNewsPrefetchTask = Task(priority: .utility) {
                    await CachedAsyncImageHelper.prefetchImages(from: prefetchURLs)
                }
            }
        } catch {
            print("❌ Error loading saved news: \(error)")
            await MainActor.run {
                savedNews = []
                savedRelatedNewsByNeutralId = [:]
            }
        }
    }

    /// Removes a news item from the saved news array (UI state only).
    ///
    /// This only removes the item from the in-memory array. To permanently delete from Core Data,
    /// use `SavedNewsService.deleteSavedNews()`.
    ///
    /// - Parameter newsId: The ID of the news item to remove from the array
    func removeFromSavedNews(_ newsId: String) {
        savedNews.removeAll { $0.id == newsId }
        savedRelatedNewsByNeutralId.removeValue(forKey: newsId)
    }
}
