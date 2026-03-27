//
//  NeutralNewsOptionsMenu.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct NeutralNewsOptionsMenu: View {
    let news: NeutralNews
    let relatedNews: [News]
    @Binding var isShowingReportProblemSheet: Bool

    private let premiumManager = PremiumManager.shared
    @State private var savedNewsState = SavedNewsState.shared
    @State private var saveFeedbackTrigger = 0
    @State private var savedRegionRawSnapshot: String?

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
                let saved = currentSavedStatus
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
        if savedRegionRawSnapshot == nil {
            savedRegionRawSnapshot = NewsListViewModel.shared.savedRegionRaw(for: news.id)
        }

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
            let currentlySaved = currentSavedStatus

            if currentlySaved {
#if DEBUG
                print("🗑️ Unsaving article...")
#endif
                let unsaveRegionRaw = NewsListViewModel.shared.isShowingSavedNews
                    ? currentSavedRegionRaw
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
                let savedRegionRaw = currentSavedRegionRaw ?? ContentRegionProvider().currentRegion.rawValue
                try SavedNewsService.shared.saveNews(news, context: context, regionRaw: savedRegionRaw)
                await MainActor.run {
                    savedNewsState.setSaved(true, for: news.id, regionRaw: savedRegionRaw)
                    savedRegionRawSnapshot = savedRegionRaw

                    if NewsListViewModel.shared.isShowingSavedNews {
                        NewsListViewModel.shared.restoreSavedNews(
                            news,
                            relatedNews: relatedNews,
                            regionRaw: savedRegionRaw
                        )
                    }

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

    private var currentSavedStatus: Bool {
        let regionRaw = currentSavedRegionRaw
        return savedNewsState.isSaved(news.id, regionRaw: regionRaw)
    }

    private var currentSavedRegionRaw: String? {
        let vm = NewsListViewModel.shared
        if vm.isShowingSavedNews {
            return vm.savedRegionRaw(for: news.id) ?? savedRegionRawSnapshot
        }

        return savedRegionRawSnapshot
    }
}
