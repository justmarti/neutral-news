//
//  NewsImageView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI

struct NewsImageView: View {
    let news: NeutralNews
    let imageUrl: String?
    @Environment(\.displayScale) private var displayScale
    @State private var loadedImage: UIImage?
    @State private var loadedImageIdentifier: String?
    @State private var focusPoint: ImageFocusPoint?
    private static let cardHeight: CGFloat = 250
    private static let cornerRadius: CGFloat = 16

    // Gradient is created once and shared by all instances
    private static let overlayGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color.black.opacity(0),
            Color.black.opacity(0.2),
            Color.black.opacity(0.8),
            Color.black.opacity(0.9),
            Color.black.opacity(1)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        GeometryReader { geometry in
            let imageIdentifier = imageLoadIdentifier(width: geometry.size.width)

            ZStack(alignment: .bottom) {
                Group {
                    if let loadedImage,
                       loadedImageIdentifier == imageIdentifier {
                        let metrics = ImageCrop.metrics(
                            imageSize: loadedImage.size,
                            containerSize: CGSize(
                                width: geometry.size.width,
                                height: Self.cardHeight
                            ),
                            focusPoint: focusPoint,
                            focusTargetY: ImageFocusConfiguration.headlineOverlayFocusTargetY
                        )

                        Image(uiImage: loadedImage)
                            .resizable()
                            .frame(
                                width: metrics.renderedSize.width,
                                height: metrics.renderedSize.height
                            )
                            .offset(x: metrics.offset.width, y: metrics.offset.height)
                            .frame(width: geometry.size.width, height: Self.cardHeight)
                            .clipped()
                    } else {
                        ShimmerView()
                            .frame(width: geometry.size.width, height: Self.cardHeight)
                    }
                }
                .task(id: imageIdentifier) {
                    await loadImage(width: geometry.size.width, identifier: imageIdentifier)
                }
                
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(height: 180)
                    .mask(Self.overlayGradient)
                
                Text(news.neutralTitle)
                    .padding(.horizontal, 12)
                    .padding(.vertical)
                    .font(.system(size: 22, design: .serif))
//                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geometry.size.width, height: Self.cardHeight)
        }
        .frame(height: Self.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .contentShape(.interaction, RoundedRectangle(cornerRadius: Self.cornerRadius))
    }

    private func loadImage(width: CGFloat, identifier: String) async {
        loadedImage = nil
        loadedImageIdentifier = identifier
        focusPoint = nil

        guard let imageUrl,
              let url = URL(string: imageUrl) else {
            return
        }

        do {
            let image = try await CachedAsyncImageHelper.loadUIImage(
                url: url,
                maxPixelSize: imageLoadMaxPixelSize(width: width)
            )
            try Task.checkCancellation()
            let resolvedFocusPoint = await ImageFocusResolver.focusPoint(
                for: url,
                image: image
            )

            guard !Task.isCancelled,
                  loadedImageIdentifier == identifier else {
                return
            }

            focusPoint = resolvedFocusPoint
            loadedImage = image
        } catch is CancellationError {
            return
        } catch {
            guard loadedImageIdentifier == identifier else { return }
            loadedImage = nil
            focusPoint = nil
        }
    }

    private func imageLoadIdentifier(width: CGFloat) -> String {
        "\(imageUrl ?? "nil")|\(Int(imageLoadMaxPixelSize(width: width).rounded()))"
    }

    private func imageLoadMaxPixelSize(width: CGFloat) -> Double {
        Double(width * displayScale)
    }
}

#Preview {
    NewsImageView(
        news: NeutralNews.mock,
        imageUrl: "https://www.lavanguardia.com/files/og_thumbnail/files/fp/uploads/2025/04/22/68075b725f598.r_d.1714-2017-0.jpeg"
    )
    .padding()
}
