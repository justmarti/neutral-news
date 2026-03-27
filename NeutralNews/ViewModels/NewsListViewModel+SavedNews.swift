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

    /// Loads all saved news from persistent storage.
    ///
    /// Fetches saved news items, converts them back to `NeutralNews` objects,
    /// and updates the `savedNews` array for display.
    ///
    /// - Note: Uses SwiftData as primary store and Core Data as temporary migration fallback.
    /// - Note: This is an async operation that updates `isLoadingSavedNews` state
    func loadSavedNews() async {
#if DEBUG
        print("🔄 Loading saved news")
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
            let savedNewsItems = try savedNewsService.getSavedNeutralNews(context: coreDataContext)
#if DEBUG
            print("📰 Found \(savedNewsItems.count) saved news items")
#endif

            let parsedSavedItems = savedNewsItems.map { savedNews -> (neutral: NeutralNews, related: [News], regionRaw: String) in
                (neutral: savedNews.neutralNews, related: savedNews.relatedNews, regionRaw: savedNews.regionRaw)
            }

#if DEBUG
            print("✅ Successfully parsed \(parsedSavedItems.count) neutral news items")
#endif

            await MainActor.run {
                let activeRegionRaw = ContentRegionProvider().currentRegion.rawValue
                let sortedSavedItems = parsedSavedItems.sorted { lhs, rhs in
                    let lhsIsActiveRegion = lhs.regionRaw == activeRegionRaw
                    let rhsIsActiveRegion = rhs.regionRaw == activeRegionRaw

                    if lhsIsActiveRegion != rhsIsActiveRegion {
                        return lhsIsActiveRegion
                    }

                    return lhs.neutral.date > rhs.neutral.date
                }
                var seenNewsIds = Set<String>()
                var deduplicatedNews: [NeutralNews] = []
                var deduplicatedRelatedNewsById: [String: [News]] = [:]
                var deduplicatedRegionById: [String: String] = [:]

                for item in sortedSavedItems {
                    let newsId = item.neutral.id
                    guard seenNewsIds.insert(newsId).inserted else { continue }

                    deduplicatedNews.append(item.neutral)
                    deduplicatedRelatedNewsById[newsId] = item.related
                    deduplicatedRegionById[newsId] = item.regionRaw
                }

                savedNews = deduplicatedNews
                savedRelatedNewsByNeutralId = deduplicatedRelatedNewsById
                savedRegionByNewsId = deduplicatedRegionById
                for item in sortedSavedItems {
                    SavedNewsState.shared.setSaved(true, for: item.neutral.id, regionRaw: item.regionRaw)
                }
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
                savedRegionByNewsId = [:]
            }
        }
    }

    /// Removes a news item from the saved news array (UI state only).
    ///
    /// This only removes the item from in-memory UI state.
    ///
    /// - Parameter newsId: The ID of the news item to remove from the array
    func removeFromSavedNews(_ newsId: String) {
        savedNews.removeAll { $0.id == newsId }
        savedRelatedNewsByNeutralId.removeValue(forKey: newsId)
        savedRegionByNewsId.removeValue(forKey: newsId)
    }

    func restoreSavedNews(_ news: NeutralNews, relatedNews: [News], regionRaw: String) {
        if let existingIndex = savedNews.firstIndex(where: { $0.id == news.id }) {
            savedNews[existingIndex] = news
        } else {
            savedNews.append(news)
        }

        savedRelatedNewsByNeutralId[news.id] = relatedNews
        savedRegionByNewsId[news.id] = regionRaw

        let activeRegionRaw = ContentRegionProvider().currentRegion.rawValue
        savedNews.sort { lhs, rhs in
            let lhsRegionRaw = savedRegionByNewsId[lhs.id] ?? activeRegionRaw
            let rhsRegionRaw = savedRegionByNewsId[rhs.id] ?? activeRegionRaw
            let lhsIsActiveRegion = lhsRegionRaw == activeRegionRaw
            let rhsIsActiveRegion = rhsRegionRaw == activeRegionRaw

            if lhsIsActiveRegion != rhsIsActiveRegion {
                return lhsIsActiveRegion
            }

            return lhs.date > rhs.date
        }
    }

    func savedRegionRaw(for newsId: String) -> String? {
        savedRegionByNewsId[newsId]
    }
}
