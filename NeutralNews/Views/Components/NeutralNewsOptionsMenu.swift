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
                    premiumManager.requirePremium(for: "save_news")
                }
            } label: {
                Label(
                    isArticleSaved ? "Quitar de guardadas" : "Guardar",
                    systemImage: isArticleSaved ? "bookmark.fill" : "bookmark"
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
        print("🔄 Attempting to save article: \(news.id)")
        do {
            if isArticleSaved {
                print("🗑️ Unsaving article...")
                try SavedNewsService.shared.unsaveNews(newsId: news.id, context: context)
                isArticleSaved = false
                print("✅ Article unsaved successfully")
                // Remove from saved news list if currently viewing saved news
                await MainActor.run {
                    NewsListViewModel.shared.removeFromSavedNews(news.id)
                }
            } else {
                print("💾 Saving article...")
                try SavedNewsService.shared.saveNews(news, context: context)
                isArticleSaved = true
                print("✅ Article saved successfully")
            }
        } catch {
            print("❌ Error saving/unsaving article: \(error)")
        }
    }
    
    private func generateShareURL() -> URL {
        return DeepLinkService.generateShareURL(for: news)
    }
}
