//
//  NewsListViewModel+DeepLink.swift
//  NeutralNews
//

import Foundation

extension NewsListViewModel {
    private enum DeepLinkLookupResult: Sendable, Equatable {
        case found(DeepLinkNavigationTarget)
        case notFound
        case timedOut
    }

    /// Handles incoming deep link requests to navigate to a specific news article.
    ///
    /// If news data is already loaded, processes the deep link immediately. Otherwise, stores it
    /// as pending and resolves it once the initial launch load finishes.
    ///
    /// - Parameter deepLinkData: The deep link data containing the target news ID
    /// - Note: Sets `isLoadingNeutralNews` to `true` during processing
    /// - Important: Automatically clears loading state once article is found or timeout occurs (10s)
    func handleDeepLink(_ deepLinkData: DeepLinkService.DeepLinkData) {
        isLoadingNeutralNews = true
        isResolvingDeepLink = true
        AppFeedbackCenter.shared.showLoading("Opening article")

        if hasCompletedInitialLaunchLoad || !newsDataManager.neutralNews.isEmpty {
            processDeepLink(deepLinkData)
        } else {
            pendingDeepLink = deepLinkData
        }
    }

    func checkPendingDeepLink() {
        guard let pendingDeepLink = pendingDeepLink else { return }
        processDeepLink(pendingDeepLink)
    }

    private func processDeepLink(_ deepLinkData: DeepLinkService.DeepLinkData) {
        isResolvingDeepLink = true
#if DEBUG
        print("🔄 Processing deep link in ViewModel - newsId: \(deepLinkData.newsId), region: \(deepLinkData.region?.rawValue ?? "current")")
#endif

        let currentRegion = ContentRegionProvider().currentRegion
        let targetRegion = deepLinkData.region ?? currentRegion
        let shouldUseCurrentRegionState = targetRegion == currentRegion

        if shouldUseCurrentRegionState,
           let news = findNews(newsId: deepLinkData.newsId) {
#if DEBUG
            print("✅ News found immediately: \(news.neutralTitle)")
#endif
            completeDeepLinkLookup(with: makeDeepLinkTarget(from: news, region: targetRegion))
            return
        }

        let newsId = deepLinkData.newsId

        deepLinkLookupTask?.cancel()
        deepLinkLookupTask = Task {
            let result = await Self.resolveDeepLinkLookup(newsId: newsId, region: targetRegion)

            await MainActor.run {
                guard !Task.isCancelled else { return }

                switch result {
                case .found(let target):
                    NewsListViewModel.shared.completeDeepLinkLookup(
                        with: target,
                        cancelLookupTask: false
                    )
                case .notFound, .timedOut:
#if DEBUG
                    print("❌ News not found for deep link - newsId: \(newsId)")
#endif
                    NewsListViewModel.shared.clearPendingDeepLinkLookup(cancelLookupTask: false)
                }
            }
        }
    }

    private nonisolated static func resolveDeepLinkLookup(
        newsId: String,
        region: ContentRegion
    ) async -> DeepLinkLookupResult {
        await withTaskGroup(of: DeepLinkLookupResult.self) { group in
            group.addTask {
                do {
                    guard let lookup = try await FirestoreService.shared.fetchNeutralNewsLookup(
                        newsId: newsId,
                        region: region
                    ) else {
                        return .notFound
                    }

                    let target = DeepLinkNavigationTarget(
                        news: lookup.news,
                        relatedNews: lookup.relatedNews,
                        region: region
                    )

#if DEBUG
                    print("✅ News resolved for deep link: \(target.news.neutralTitle)")
#endif

                    return .found(target)
                } catch {
#if DEBUG
                    print("❌ News lookup failed for deep link \(newsId): \(error)")
#endif
                    return .notFound
                }
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return .timedOut
            }

            guard let result = await group.next() else {
                group.cancelAll()
                return .notFound
            }

            group.cancelAll()
            return result
        }
    }

    private func completeDeepLinkLookup(with target: DeepLinkNavigationTarget, cancelLookupTask: Bool = true) {
        if cancelLookupTask {
            deepLinkLookupTask?.cancel()
        }
        deepLinkLookupTask = nil
        deepLinkTargetNews = target
        pendingDeepLink = nil
        isResolvingDeepLink = false
        AppFeedbackCenter.shared.dismiss()
        isLoadingNeutralNews = false
        hasCompletedInitialLaunchLoad = true
    }

    private func clearPendingDeepLinkLookup(cancelLookupTask: Bool = true) {
        if cancelLookupTask {
            deepLinkLookupTask?.cancel()
        }
        deepLinkLookupTask = nil
        pendingDeepLink = nil
        isResolvingDeepLink = false
        AppFeedbackCenter.shared.show("Article not found", systemImage: "exclamationmark.triangle", style: .error)
        isLoadingNeutralNews = false
        hasCompletedInitialLaunchLoad = true
    }

    private func findNews(newsId: String) -> NeutralNews? {
        newsDataManager.neutralNews.first { news in
            news.id == newsId
        }
    }

    private func makeDeepLinkTarget(from news: NeutralNews, region: ContentRegion) -> DeepLinkNavigationTarget {
        DeepLinkNavigationTarget(
            news: news,
            relatedNews: getRelatedNews(from: news),
            region: region
        )
    }
}
