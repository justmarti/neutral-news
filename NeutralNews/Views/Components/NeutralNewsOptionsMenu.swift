//
//  NeutralNewsOptionsMenu.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct NeutralNewsOptionsActions: View {
    let news: NeutralNews
    let relatedNews: [News]
    let region: ContentRegion?
    @Binding var isShowingReportProblemSheet: Bool

    private let premiumManager = PremiumManager.shared
    @State private var savedNewsState = SavedNewsState.shared
    @State private var savedRegionRawSnapshot: String?

    var body: some View {
        Group {
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
        }
        .task {
            await ensureSavedStatusLoadedIfNeeded()
        }
    }

    private func ensureSavedStatusLoadedIfNeeded() async {
        if savedRegionRawSnapshot == nil {
            savedRegionRawSnapshot = NewsListViewModel.shared.savedRegionRaw(for: news.id) ?? region?.rawValue
        }

        guard !NewsListViewModel.shared.isShowingSavedNews else { return }
        let regionRaw = currentSavedRegionRaw
        guard !savedNewsState.hasStatus(for: news.id, regionRaw: regionRaw) else { return }

        let isSaved = SavedNewsService.shared.isNewsSaved(
            newsId: news.id,
            context: NewsListViewModel.shared.coreDataContext,
            regionRaw: regionRaw
        )
        await MainActor.run {
            savedNewsState.setSaved(isSaved, for: news.id, regionRaw: regionRaw)
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
                    AppFeedbackCenter.shared.show("Removed from saved", systemImage: "bookmark.slash", style: .info, haptic: .success)
                }
#if DEBUG
                print("✅ Article unsaved successfully")
#endif
                await MainActor.run {
                    NewsListViewModel.shared.removeFromSavedNews(news.id)
                }
            } else {
#if DEBUG
                print("💾 Saving article...")
#endif
                let savedRegionRaw = currentSavedRegionRaw ?? ContentRegionProvider().currentRegion.rawValue
                try SavedNewsService.shared.saveNews(
                    news,
                    context: context,
                    regionRaw: savedRegionRaw,
                    relatedNews: relatedNews
                )
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

                    AppFeedbackCenter.shared.show("Saved", systemImage: "bookmark", style: .success)
                }
#if DEBUG
                print("✅ Article saved successfully")
#endif
            }
        } catch {
            print("❌ Error saving/unsaving article: \(error)")
            await MainActor.run {
                AppFeedbackCenter.shared.show("Couldn’t update saved news", systemImage: "exclamationmark.triangle", style: .error)
            }
        }
    }

    private func generateShareURL() -> URL {
        DeepLinkService.generateShareURL(for: news, region: shareRegion)
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

        return savedRegionRawSnapshot ?? region?.rawValue
    }

    private var shareRegion: ContentRegion {
        if let regionRaw = currentSavedRegionRaw,
           let resolvedRegion = ContentRegion(rawValue: regionRaw) {
            return resolvedRegion
        }

        return region ?? ContentRegionProvider().currentRegion
    }
}

struct NeutralNewsOptionsMenu: View {
    let news: NeutralNews
    let relatedNews: [News]
    let region: ContentRegion?
    @Binding var isShowingReportProblemSheet: Bool

    var body: some View {
        Menu {
            NeutralNewsOptionsActions(
                news: news,
                relatedNews: relatedNews,
                region: region,
                isShowingReportProblemSheet: $isShowingReportProblemSheet
            )
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline.weight(.semibold))
                .accessibilityLabel("Options")
        }
    }
}
