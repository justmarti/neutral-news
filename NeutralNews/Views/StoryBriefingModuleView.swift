//
//  StoryBriefingModuleView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 24/4/26.
//

import SwiftUI

struct StoryBriefingModuleView: View {
    let collection: StoryCollection
    let action: (NeutralNews) -> Void
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var dominantColor: Color = .nnBackground
    @State private var currentItemIndex = 0
    @State private var previousItem: NeutralNews?
    @State private var thumbnailTransitionProgress: CGFloat = 1

    private let imageService = ImageService.shared
    private let rotationInterval: Duration = .seconds(4)
    private let transitionAnimation = Animation.easeInOut(duration: 0.5)
    private let thumbnailAnimation = Animation.smooth(duration: 0.65)
    private let thumbnailSize = CGSize(width: 88, height: 112)

    var body: some View {
        Button {
            action(currentItem)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected stories")
                        .font(.title2)
                        .bold()
                        .fontDesign(.serif)
                        .foregroundStyle(.primary)

                    Text("A quick summary of the latest news.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                thumbnailView
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.clear)
                    .overlay {
                        dominantColor.adaptiveBackground
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .animation(transitionAnimation, value: dominantColor)
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .task(id: taskConfigurationID) {
            currentItemIndex = 0
            previousItem = nil
            thumbnailTransitionProgress = 1

            async let prefetchedThumbnails = prefetchThumbnailImages()
            async let prefetchedFocusPoints: Void = prefetchImageFocusPoints()
            dominantColor = await dominantColor(for: currentItem.imageUrl)

            await prefetchedThumbnails
            await prefetchedFocusPoints

            guard items.count > 1, !accessibilityReduceMotion else { return }

            var nextIndex = 1

            while !Task.isCancelled {
                let targetIndex = nextIndex
                async let prefetchedColor = dominantColor(for: items[targetIndex].imageUrl)

                do {
                    try await Task.sleep(for: rotationInterval)
                } catch {
                    break
                }

                let nextDominantColor = await prefetchedColor
                guard !Task.isCancelled else { break }

                transitionToItem(at: targetIndex, dominantColor: nextDominantColor)

                nextIndex = (targetIndex + 1) % items.count
            }
        }
    }

    private var thumbnailView: some View {
        ZStack {
            if let previousItem {
                briefingThumbnail(for: previousItem)
                    .offset(x: -18 * thumbnailTransitionProgress)
                    .scaleEffect(1 - (0.03 * thumbnailTransitionProgress))
                    .opacity(1 - thumbnailTransitionProgress)
            }

            briefingThumbnail(for: currentItem)
                .offset(x: 18 * (1 - thumbnailTransitionProgress))
                .scaleEffect(0.97 + (0.03 * thumbnailTransitionProgress))
                .opacity(thumbnailTransitionProgress)
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var items: [NeutralNews] {
        collection.items.isEmpty ? [collection.coverNews] : collection.items
    }

    private var currentItem: NeutralNews {
        items[currentItemIndex % items.count]
    }

    private var taskConfigurationID: String {
        let ids = items.map(\.id).joined(separator: "|")
        return "\(ids)|motion:\(accessibilityReduceMotion)"
    }

    @ViewBuilder
    private func briefingThumbnail(for news: NeutralNews) -> some View {
        if let url = URL(string: news.imageUrl),
           let cachedImage = CachedAsyncImageHelper.cachedUIImage(
            url: url,
            maxPixelSize: thumbnailPixelSize
           ) {
            Image(uiImage: cachedImage)
                .resizable()
                .scaledToFill()
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipped()
                .id(news.id)
        } else {
            CachedAsyncImage(url: URL(string: news.imageUrl), maxPixelSize: thumbnailPixelSize) { phase in
                switch phase {
                case .empty:
                    ShimmerView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(.quaternary)
                @unknown default:
                    Rectangle()
                        .fill(.quaternary)
                }
            }
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .clipped()
            .id(news.id)
        }
    }

    private func dominantColor(for imageUrl: String?) async -> Color {
        return await imageService.getDominantColor(from: imageUrl)
    }

    private var thumbnailPixelSize: Double {
        max(thumbnailSize.width, thumbnailSize.height) * UIScreen.main.scale
    }

    private func prefetchThumbnailImages() async {
        let urls = items.compactMap { URL(string: $0.imageUrl) }
        await CachedAsyncImageHelper.prefetchImages(from: urls, maxPixelSize: thumbnailPixelSize)
    }

    private func prefetchImageFocusPoints() async {
        await StoryHeroImageView.prefetchFocusPoints(for: items)
    }

    @MainActor
    private func transitionToItem(at nextIndex: Int, dominantColor nextDominantColor: Color) {
        let outgoingItem = currentItem
        previousItem = outgoingItem
        currentItemIndex = nextIndex
        thumbnailTransitionProgress = 0

        withAnimation(thumbnailAnimation, completionCriteria: .logicallyComplete) {
            thumbnailTransitionProgress = 1
            dominantColor = nextDominantColor
        } completion: {
            previousItem = nil
        }
    }
}
