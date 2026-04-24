//
//  StoryArticleSheetView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 4/6/26.
//

import SwiftUI

struct StoryArticleSheetView: View {
    let news: NeutralNews
    @Binding var selectedDetent: PresentationDetent
    @Binding var collapsedHeight: CGFloat
    let visualOffset: CGFloat
    let visualOpacity: Double
    let onOpenArticle: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            StoryArticleContentView(
                news: news,
                isExpanded: isExpanded,
                onOpenArticle: onOpenArticle
            )
                .background(collapsedHeightReader)
                .contentShape(Rectangle())
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(sheetSurface)
        .offset(y: visualOffset)
        .opacity(visualOpacity)
        .onTapGesture {
            expandIfCollapsed()
        }
    }

    private var sheetSurface: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
    }

    private var isExpanded: Bool {
        selectedDetent == .large
    }

    @ViewBuilder
    private var collapsedHeightReader: some View {
        if !isExpanded {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateCollapsedHeight(proxy.size.height)
                    }
                    .onChange(of: proxy.size.height) { _, newValue in
                        updateCollapsedHeight(newValue)
                    }
            }
        }
    }

    private func updateCollapsedHeight(_ contentHeight: CGFloat) {
        let targetHeight = min(max(contentHeight + 8, 156), 280)

        guard abs(collapsedHeight - targetHeight) > 1 else { return }
        collapsedHeight = targetHeight

        if !isExpanded {
            selectedDetent = .height(targetHeight)
        }
    }

    private func expandIfCollapsed() {
        guard !isExpanded else { return }
        selectedDetent = .large
    }

    static func estimatedCollapsedHeight(for news: NeutralNews) -> CGFloat {
        let horizontalPadding: CGFloat = 48
        let estimatedOuterWidth = max(UIScreen.main.bounds.width - 32, 280)
        let textWidth = max(estimatedOuterWidth - horizontalPadding, 220)

        let titleFont = UIFont.preferredFont(forTextStyle: .title2)
        let titleHeight = (news.neutralTitle as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: titleFont],
            context: nil
        ).height

        let metadataLineHeight = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
        let estimatedHeight =
            8 +
            16 +
            metadataLineHeight +
            10 +
            ceil(titleHeight) +
            16

        return min(max(estimatedHeight + 18, 184), 280)
    }

    static func stableReservedHeight(for news: NeutralNews) -> CGFloat {
        max(estimatedCollapsedHeight(for: news), 232)
    }
}

private struct StoryArticleContentView: View {
    let news: NeutralNews
    let isExpanded: Bool
    let onOpenArticle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 20 : 10) {
            Capsule()
                .fill(.secondary.opacity(0.7))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            HStack(alignment: .center, spacing: 12) {
                Text(Category.displayName(for: news.category).uppercased())

                Spacer()

                Text(formattedStoryDate)
            }
            .padding(.top)
            .font(.subheadline)
            .fontWidth(.expanded)
            .foregroundStyle(.secondary)

            Text(news.neutralTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .fontDesign(.serif)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if isExpanded {
                Text(news.neutralDescription)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onOpenArticle) {
                    HStack {
                        Text("Read more")
                        Image(systemName: "arrow.right")
                    }
                    .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, isExpanded ? 4 : 0)
        .padding(.bottom, isExpanded ? 32 : 16)
        .contentShape(Rectangle())
    }

    private var formattedStoryDate: String {
        news.date.formatted(
            Date.FormatStyle.dateTime
                .day()
                .month(.abbreviated)
                .hour()
                .minute()
                .locale(.autoupdatingCurrent)
        ).uppercased()
    }
}
