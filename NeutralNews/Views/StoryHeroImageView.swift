//
//  StoryHeroImageView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 4/10/26.
//

import SwiftUI

struct StoryHeroImageView: View {
    let imageUrl: String
    let reservedBottomHeight: CGFloat

    private let fallbackSharpScale: CGFloat = 1.03
    private let sharpImageBottomOverlap: CGFloat = 48
    @Environment(\.displayScale) private var displayScale
    @State private var loadedUIImage: UIImage?
    @State private var loadedImageIdentifier: String?
    @State private var displayFocusPoint: ImageFocusPoint?
    @State private var displayFocusPointIdentifier: String?

    static func prefetchFocusPoints(for newsItems: [NeutralNews]) async {
        guard !newsItems.isEmpty else { return }

        let maxConcurrentPrefetches = 2
        var nextIndex = 0

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<min(maxConcurrentPrefetches, newsItems.count) {
                guard !Task.isCancelled else { return }

                let imageUrl = newsItems[nextIndex].imageUrl
                nextIndex += 1
                group.addTask {
                    await prefetchFocusPoint(for: imageUrl)
                }
            }

            while await group.next() != nil {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }

                guard nextIndex < newsItems.count else { continue }

                let imageUrl = newsItems[nextIndex].imageUrl
                nextIndex += 1
                group.addTask {
                    await prefetchFocusPoint(for: imageUrl)
                }
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let topInset: CGFloat = 65
            let reservedSharpBottomHeight = max(reservedBottomHeight - sharpImageBottomOverlap, 0)
            let sharpHeight = max(size.height - reservedSharpBottomHeight - topInset, 0)
            let resolvedUIImage = resolvedUIImage(size: size)
            let effectiveFocusPoint = displayFocusPointIdentifier == imageFocusIdentifier
                ? displayFocusPoint
                : nil
            let heroContainerSize = CGSize(width: size.width, height: sharpHeight)
            let backgroundContainerSize = CGSize(width: size.width, height: size.height)
            let heroMetrics = resolvedUIImage.map {
                storyImageMetrics(
                    uiImage: $0,
                    containerSize: heroContainerSize,
                    focusPoint: effectiveFocusPoint
                )
            }
            let backgroundMetrics = resolvedUIImage.map {
                storyImageMetrics(
                    uiImage: $0,
                    containerSize: backgroundContainerSize,
                    focusPoint: effectiveFocusPoint
                )
            }

            ZStack {
                Group {
                    if let uiImage = resolvedUIImage,
                       let backgroundMetrics {
                        renderedStoryImage(
                            uiImage: uiImage,
                            metrics: backgroundMetrics,
                            containerSize: size
                        )
                        .blur(radius: 28)
                        .saturation(0.95)
                    } else {
                        LinearGradient(
                            colors: [.black.opacity(0.85), .gray.opacity(0.55), .black.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: size.width, height: size.height)
                    }
                }
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        Group {
                            if let uiImage = resolvedUIImage,
                               let heroMetrics {
                                renderedStoryImage(
                                    uiImage: uiImage,
                                    metrics: heroMetrics,
                                    containerSize: heroContainerSize
                                )
                            } else {
                                ShimmerView()
                                    .frame(width: size.width, height: sharpHeight)
                            }
                        }
                        .task(id: imageLoadIdentifier(size: size)) {
                            await loadImage(size: size)
                        }
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.08),
                                    .init(color: .black, location: 0.84),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .frame(width: size.width, height: sharpHeight)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, topInset)
                .allowsHitTesting(false)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.02), location: 0),
                        .init(color: .clear, location: 0.2),
                        .init(color: .clear, location: 0.6),
                        .init(color: .black.opacity(0.18), location: 0.82),
                        .init(color: .black.opacity(0.34), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }

    private func loadImage(size: CGSize) async {
        guard let url = URL(string: imageUrl) else {
            loadedUIImage = nil
            loadedImageIdentifier = nil
            displayFocusPoint = nil
            displayFocusPointIdentifier = nil
            return
        }

        let imageIdentifier = imageLoadIdentifier(size: size)
        let focusIdentifier = imageFocusIdentifier
        let maxPixelSize = imageLoadMaxPixelSize(size: size)

        loadedImageIdentifier = imageIdentifier
        loadedUIImage = nil
        displayFocusPoint = nil
        displayFocusPointIdentifier = nil

        do {
            let image = try await CachedAsyncImageHelper.loadUIImage(url: url, maxPixelSize: maxPixelSize)
            let focusPoint = await ImageFocusResolver.focusPoint(for: url)

            guard !Task.isCancelled, loadedImageIdentifier == imageIdentifier else { return }

            displayFocusPoint = focusPoint
            displayFocusPointIdentifier = focusIdentifier
            loadedUIImage = image
        } catch {
            guard loadedImageIdentifier == imageIdentifier else { return }
            loadedUIImage = nil
            displayFocusPoint = nil
            displayFocusPointIdentifier = nil
        }
    }

    private func imageLoadIdentifier(size: CGSize) -> String {
        "\(imageUrl)|\(Int(imageLoadMaxPixelSize(size: size).rounded()))"
    }

    private var imageFocusIdentifier: String {
        imageUrl
    }

    private static func prefetchFocusPoint(for imageUrl: String) async {
        guard let url = URL(string: imageUrl) else { return }
        _ = await ImageFocusResolver.focusPoint(for: url)
    }

    private func imageLoadMaxPixelSize(size: CGSize) -> Double {
        Double(max(size.width, size.height) * displayScale)
    }

    private func resolvedUIImage(size: CGSize) -> UIImage? {
        guard loadedImageIdentifier == imageLoadIdentifier(size: size) else {
            return nil
        }

        return loadedUIImage
    }

    @ViewBuilder
    private func renderedStoryImage(
        uiImage: UIImage,
        metrics: ImageCropMetrics,
        containerSize: CGSize
    ) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .frame(width: metrics.renderedSize.width, height: metrics.renderedSize.height)
            .offset(x: metrics.offset.width, y: metrics.offset.height)
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
    }

    private func storyImageMetrics(
        uiImage: UIImage,
        containerSize: CGSize,
        focusPoint: ImageFocusPoint?
    ) -> ImageCropMetrics {
        ImageCrop.metrics(
            imageSize: uiImage.size,
            containerSize: containerSize,
            focusPoint: focusPoint,
            fallbackScale: fallbackSharpScale
        )
    }
}
