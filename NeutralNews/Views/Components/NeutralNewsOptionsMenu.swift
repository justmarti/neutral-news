//
//  NeutralNewsOptionsMenu.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI
import SwiftData

struct NeutralNewsOptionsMenu: View {
    let news: NeutralNews
    @Binding var isShowingReportProblemSheet: Bool

    private let premiumManager = PremiumManager.shared
    @State private var isArticleSaved = false

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
                Label(
                    isArticleSaved ? "Quitar de guardadas" : "Guardar",
                    systemImage: !premiumManager.canSaveNews ? "lock.fill" : (isArticleSaved ? "bookmark.fill" : "bookmark")
                )
            }

            ShareLink(item: generateShareURL()) {
                Label("Compartir", systemImage: "square.and.arrow.up")
            }

            Button {
                isShowingReportProblemSheet.toggle()
            } label: {
                Label("Reportar problema", systemImage: "exclamationmark.bubble")
            }

        } label: {
            Label("Opciones", systemImage: "ellipsis")
        }
        .task {
            await checkIfArticleIsSaved()
        }
    }

    private func checkIfArticleIsSaved() async {
        guard let context = NewsListViewModel.shared.coreDataContext else { return }
        isArticleSaved = SavedNewsService.shared.isNewsSaved(newsId: news.id, context: context)
    }

    private func handleSaveArticle() async {
        guard let context = NewsListViewModel.shared.coreDataContext else { return }
#if DEBUG
        print("🔄 Attempting to save article: \(news.id)")
#endif
        do {
            if isArticleSaved {
#if DEBUG
                print("🗑️ Unsaving article...")
#endif
                try SavedNewsService.shared.unsaveNews(newsId: news.id, context: context)
                isArticleSaved = false
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
                isArticleSaved = true
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
