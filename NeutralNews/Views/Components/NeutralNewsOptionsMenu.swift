//
//  NeutralNewsOptionsMenu.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct NeutralNewsOptionsMenu: View {
    let news: NeutralNews
    @Binding var isShowingReportProblemSheet: Bool

    private let premiumManager = PremiumManager.shared
    @State private var savedNewsState = SavedNewsState.shared
    @State private var saveFeedbackTrigger = 0

    var body: some View {
        Menu {
            Button {
                if premiumManager.canSaveNews {
                    Task {
                        await handleSaveArticle()
                    }
                } else {
                    premiumManager.requirePremium(for: "save_news") {
                        Task {
                            await handleSaveArticle()
                        }
                    }
                }
            } label: {
                let saved = NewsListViewModel.shared.isShowingSavedNews ? true : savedNewsState.isSaved(news.id)
                Label(
                    saved ? "Saved" : "Save",
                    systemImage: !premiumManager.canSaveNews
                        ? "lock.fill"
                        : (saved ? "bookmark.fill" : "bookmark")
                )
            }

            ShareLink(item: generateShareURL()) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                isShowingReportProblemSheet.toggle()
            } label: {
                Label("Report a problem", systemImage: "exclamationmark.bubble")
            }

        } label: {
            Label("Options", systemImage: "ellipsis")
        }
        .sensoryFeedback(.success, trigger: saveFeedbackTrigger)
        .task {
            await ensureSavedStatusLoadedIfNeeded()
        }
    }

    private func ensureSavedStatusLoadedIfNeeded() async {
        guard !NewsListViewModel.shared.isShowingSavedNews else { return }
        guard !savedNewsState.hasStatus(for: news.id) else { return }

        let isSaved = SavedNewsService.shared.isNewsSaved(newsId: news.id, context: NewsListViewModel.shared.coreDataContext)
        await MainActor.run {
            savedNewsState.setSaved(isSaved, for: news.id)
        }
    }

    private func handleSaveArticle() async {
        let context = NewsListViewModel.shared.coreDataContext
#if DEBUG
        print("🔄 Attempting to save article: \(news.id)")
#endif
        do {
            let currentlySaved = NewsListViewModel.shared.isShowingSavedNews
                ? true
                : savedNewsState.isSaved(news.id)

            if currentlySaved {
#if DEBUG
                print("🗑️ Unsaving article...")
#endif
                let unsaveRegionRaw = NewsListViewModel.shared.isShowingSavedNews
                    ? NewsListViewModel.shared.savedRegionRaw(for: news.id)
                    : nil
                try SavedNewsService.shared.unsaveNews(newsId: news.id, context: context, regionRaw: unsaveRegionRaw)
                await MainActor.run {
                    savedNewsState.setSaved(false, for: news.id, regionRaw: unsaveRegionRaw)
                    saveFeedbackTrigger &+= 1
                }
#if DEBUG
                print("✅ Article unsaved successfully")
#endif
                // Remove from saved news list if currently viewing saved news
                await MainActor.run {
                    NewsListViewModel.shared.removeFromSavedNews(news.id)
                }
            } else {
#if DEBUG
                print("💾 Saving article...")
#endif
                try SavedNewsService.shared.saveNews(news, context: context)
                await MainActor.run {
                    savedNewsState.setSaved(true, for: news.id)
                    saveFeedbackTrigger &+= 1
                }
#if DEBUG
                print("✅ Article saved successfully")
#endif
            }
        } catch {
            print("❌ Error saving/unsaving article: \(error)")
        }
    }
    
    private func generateShareURL() -> URL {
        return DeepLinkService.generateShareURL(for: news)
    }
}
