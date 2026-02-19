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

            let neutralNewsList = savedNewsItems.compactMap { savedNews -> NeutralNews? in
                guard savedNews.newsType == SavedNewsType.neutralNews.rawValue else {
#if DEBUG
                    print("⚠️ Skipping non-neutral news: \(savedNews.newsType ?? "unknown")")
#endif
                    return nil
                }

                return savedNews.toNeutralNews()
            }

#if DEBUG
            print("✅ Successfully parsed \(neutralNewsList.count) neutral news items")
#endif

            await MainActor.run {
                savedNews = neutralNewsList.sorted { $0.date > $1.date }
                SavedNewsState.shared.markSaved(newsIds: savedNews.map(\.id))
#if DEBUG
                print("🎯 savedNews updated with \(savedNews.count) items")
#endif
            }

            let prefetchURLs = neutralNewsList
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
    }
}
