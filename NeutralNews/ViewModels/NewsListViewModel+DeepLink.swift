//
//  NewsListViewModel+DeepLink.swift
//  NeutralNews
//

import Foundation
import Observation

extension NewsListViewModel {
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

        if !newsDataManager.neutralNews.isEmpty {
            processDeepLink(deepLinkData)
        } else {
            pendingDeepLink = deepLinkData
        }
    }

    func checkPendingDeepLink() {
        guard let pendingDeepLink = pendingDeepLink,
              !newsDataManager.neutralNews.isEmpty else { return }
        processDeepLink(pendingDeepLink)
    }

    private func processDeepLink(_ deepLinkData: DeepLinkService.DeepLinkData) {
#if DEBUG
        print("🔄 Processing deep link in ViewModel - newsId: \(deepLinkData.newsId)")
#endif

        if let news = findNews(newsId: deepLinkData.newsId) {
#if DEBUG
            print("✅ News found immediately: \(news.neutralTitle)")
#endif
            deepLinkTargetNews = news
            pendingDeepLink = nil
            isLoadingNeutralNews = false
            hasCompletedInitialLaunchLoad = true
            return
        }

#if DEBUG
        print("⏳ News not loaded yet, listening for updates...")
#endif

        Task {
            await withTaskGroup(of: Bool.self) { group in
                group.addTask {
                    for await newsArray in self.newsUpdatesStream {
                        if let news = newsArray.first(where: { $0.id == deepLinkData.newsId }) {
#if DEBUG
                            print("✅ News found reactively: \(news.neutralTitle)")
#endif
                            await MainActor.run {
                                self.deepLinkTargetNews = news
                                self.pendingDeepLink = nil
                                self.isLoadingNeutralNews = false
                                self.hasCompletedInitialLaunchLoad = true
                            }
                            return true
                        }
                    }
                    return false
                }

                group.addTask {
                    do {
                        guard let news = try await FirestoreService.shared.fetchNeutralNews(newsId: deepLinkData.newsId) else {
                            return false
                        }

#if DEBUG
                        print("✅ News fetched directly from Firestore: \(news.neutralTitle)")
#endif

                        await MainActor.run {
                            self.deepLinkTargetNews = news
                            self.pendingDeepLink = nil
                            self.isLoadingNeutralNews = false
                            self.hasCompletedInitialLaunchLoad = true
                        }
                        return true
                    } catch {
#if DEBUG
                        print("❌ Direct Firestore fetch failed for deep link \(deepLinkData.newsId): \(error)")
#endif
                        return false
                    }
                }

                group.addTask {
                    try? await Task.sleep(for: .seconds(10))
                    return false
                }

                if let found = await group.next(), found {
                    group.cancelAll()
                } else {
#if DEBUG
                    print("❌ News not found within timeout - newsId: \(deepLinkData.newsId)")
#endif
                    await MainActor.run {
                        self.pendingDeepLink = nil
                        self.isLoadingNeutralNews = false
                        self.hasCompletedInitialLaunchLoad = true
                    }
                    group.cancelAll()
                }
            }
        }
    }

    private func findNews(newsId: String) -> NeutralNews? {
        newsDataManager.neutralNews.first { news in
            news.id == newsId
        }
    }
}
