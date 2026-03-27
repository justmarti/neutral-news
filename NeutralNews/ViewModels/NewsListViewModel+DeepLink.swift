//
//  NewsListViewModel+DeepLink.swift
//  NeutralNews
//

import Foundation
import Observation

extension NewsListViewModel {
    private enum DeepLinkLookupResult: Sendable, Equatable {
        case found
        case notFound
        case timedOut
    }

    // MARK: - Reactive News Updates Stream

    /// Creates an AsyncStream that emits whenever news data is updated
    private var newsUpdatesStream: AsyncStream<[NeutralNews]> {
        AsyncStream { continuation in
            // Emit current value immediately
            continuation.yield(newsDataManager.neutralNews)

            let streamState = ObservationStreamState()
            observeNewsChanges(for: continuation, streamState: streamState)

            continuation.onTermination = { _ in
                Task {
                    await streamState.terminate()
                }
            }
        }
    }

    private func observeNewsChanges(
        for continuation: AsyncStream<[NeutralNews]>.Continuation,
        streamState: ObservationStreamState
    ) {
        withObservationTracking {
            _ = newsDataManager.neutralNews
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard await streamState.canContinue() else { return }
                continuation.yield(self.newsDataManager.neutralNews)
                self.observeNewsChanges(for: continuation, streamState: streamState)
            }
        }
    }

    /// Handles incoming deep link requests to navigate to a specific news article.
    ///
    /// If news data is already loaded, processes the deep link immediately. Otherwise, stores it
    /// as pending and waits for news to load. Uses reactive AsyncStream for efficient waiting.
    ///
    /// - Parameter deepLinkData: The deep link data containing the target news ID
    /// - Note: Sets `isLoadingNeutralNews` to `true` during processing
    /// - Important: Automatically clears loading state once article is found or timeout occurs (10s)
    func handleDeepLink(_ deepLinkData: DeepLinkService.DeepLinkData) {
        isLoadingNeutralNews = true

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
            completeDeepLinkLookup(with: makeDeepLinkTarget(from: news))
            return
        }

#if DEBUG
        print("⏳ News not loaded yet, listening for updates...")
#endif

        let newsId = deepLinkData.newsId
        let newsUpdatesStream = shouldUseCurrentRegionState ? self.newsUpdatesStream : nil

        deepLinkLookupTask?.cancel()
        deepLinkLookupTask = Task {
            await withTaskGroup(of: DeepLinkLookupResult.self) { group in
                if let newsUpdatesStream {
                    group.addTask { [newsId, newsUpdatesStream] in
                        for await newsArray in newsUpdatesStream {
                            if let news = newsArray.first(where: { $0.id == newsId }) {
#if DEBUG
                                print("✅ News found reactively: \(news.neutralTitle)")
#endif
                                await MainActor.run {
                                    NewsListViewModel.shared.completeDeepLinkLookup(
                                        with: NewsListViewModel.shared.makeDeepLinkTarget(from: news)
                                    )
                                }
                                return .found
                            }
                        }
                        return .notFound
                    }
                }

                group.addTask { [newsId, targetRegion] in
                    do {
                        guard let news = try await FirestoreService.shared.fetchNeutralNews(
                            newsId: newsId,
                            region: targetRegion
                        ) else {
                            return .notFound
                        }

                        let relatedNews: [News]
                        do {
                            relatedNews = try await FirestoreService.shared.fetchNews(
                                newsIds: news.sourceIds,
                                region: targetRegion
                            )
                        } catch {
#if DEBUG
                            print("⚠️ Related news fetch failed for deep link \(newsId): \(error)")
#endif
                            relatedNews = []
                        }

                        let target = DeepLinkNavigationTarget(news: news, relatedNews: relatedNews)

#if DEBUG
                        print("✅ News fetched directly from Firestore: \(target.news.neutralTitle)")
#endif

                        await MainActor.run {
                            NewsListViewModel.shared.completeDeepLinkLookup(with: target)
                        }
                        return .found
                    } catch {
#if DEBUG
                        print("❌ Direct Firestore fetch failed for deep link \(newsId): \(error)")
#endif
                        return .notFound
                    }
                }

                group.addTask {
                    try? await Task.sleep(for: .seconds(10))
                    return .timedOut
                }

                var didFindNews = false

                while let result = await group.next() {
                    switch result {
                    case .found:
                        didFindNews = true
                        group.cancelAll()
                    case .timedOut:
                        group.cancelAll()
                    case .notFound:
                        break
                    }

                    guard !didFindNews, result != .timedOut else {
                        break
                    }
                }

                if !didFindNews {
#if DEBUG
                    print("❌ News not found within timeout - newsId: \(newsId)")
#endif
                    clearPendingDeepLinkLookup()
                    group.cancelAll()
                }
            }

            await MainActor.run {
                NewsListViewModel.shared.deepLinkLookupTask = nil
            }
        }
    }

    private func completeDeepLinkLookup(with target: DeepLinkNavigationTarget) {
        deepLinkLookupTask?.cancel()
        deepLinkLookupTask = nil
        deepLinkTargetNews = target
        pendingDeepLink = nil
        isLoadingNeutralNews = false
        hasCompletedInitialLaunchLoad = true
    }

    private func clearPendingDeepLinkLookup() {
        deepLinkLookupTask?.cancel()
        deepLinkLookupTask = nil
        pendingDeepLink = nil
        isLoadingNeutralNews = false
        hasCompletedInitialLaunchLoad = true
    }

    private func findNews(newsId: String) -> NeutralNews? {
        newsDataManager.neutralNews.first { news in
            news.id == newsId
        }
    }

    private func makeDeepLinkTarget(from news: NeutralNews) -> DeepLinkNavigationTarget {
        DeepLinkNavigationTarget(
            news: news,
            relatedNews: getRelatedNews(from: news)
        )
    }
}
