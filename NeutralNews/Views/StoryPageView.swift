//
//  StoryPageView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/28/26.
//

import SwiftUI

struct StoryPageView: View {
    let news: NeutralNews
    let onGoPrevious: () -> Void
    let onGoNext: () -> Void
    let canGoPrevious: Bool
    let canGoNext: Bool
    let nextAccessibilityLabel: String
    let reservedBottomHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                StoryHeroImageView(
                    imageUrl: news.imageUrl,
                    reservedBottomHeight: reservedBottomHeight,
                    storyFocusPoint: news.storyFocusPoint
                )

                navigationTapOverlay(
                    size: size,
                    reservedHeight: reservedBottomHeight
                )
                .zIndex(1)
            }
            .frame(width: size.width, height: size.height)
            .background(Color.black)
            .ignoresSafeArea()
        }
    }

    private func navigationTapOverlay(
        size: CGSize,
        reservedHeight: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            navigationTapZone(
                accessibilityLabel: "Previous story",
                isEnabled: canGoPrevious,
                action: onGoPrevious
            )

            navigationTapZone(
                accessibilityLabel: nextAccessibilityLabel,
                isEnabled: canGoNext,
                action: onGoNext
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(size.height - reservedHeight, 200), alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func navigationTapZone(
        accessibilityLabel: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}
