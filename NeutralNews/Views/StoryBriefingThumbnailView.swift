//
//  StoryBriefingThumbnailView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 15/7/26.
//

import SwiftUI

struct StoryBriefingThumbnailView: View {
    let imageURL: String
    let size: CGSize

    @State private var image: UIImage?
    @State private var focusPoint: ImageFocusPoint?
    @State private var hasFailedToLoad = false

    init(imageURL: String, size: CGSize, initialImage: UIImage?) {
        self.imageURL = imageURL
        self.size = size
        _image = State(initialValue: initialImage)
    }

    var body: some View {
        GeometryReader { proxy in
            if let image {
                let metrics = ImageCrop.metrics(
                    imageSize: image.size,
                    containerSize: proxy.size,
                    focusPoint: focusPoint
                )

                Image(uiImage: image)
                    .resizable()
                    .frame(width: metrics.renderedSize.width, height: metrics.renderedSize.height)
                    .offset(x: metrics.offset.width, y: metrics.offset.height)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else if hasFailedToLoad {
                Rectangle()
                    .fill(.quaternary)
            } else {
                ShimmerView()
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: taskIdentifier) {
            await loadImage()
        }
    }

    private var taskIdentifier: String {
        imageURL
    }

    private func loadImage() async {
        guard let url = URL(string: imageURL) else {
            image = nil
            focusPoint = nil
            hasFailedToLoad = true
            return
        }

        focusPoint = nil
        hasFailedToLoad = false

        do {
            let resolvedImage = try await imageForDisplay(for: url)
            let resolvedFocusPoint = await ImageFocusResolver.focusPoint(
                for: url,
                image: resolvedImage
            )

            guard !Task.isCancelled else { return }

            image = resolvedImage
            focusPoint = resolvedFocusPoint
        } catch {
            guard !Task.isCancelled else { return }
            image = nil
            focusPoint = nil
            hasFailedToLoad = true
        }
    }

    private func imageForDisplay(for url: URL) async throws -> UIImage {
        if let image {
            return image
        }

        return try await ImageFocusResolver.loadImage(for: url)
    }
}
