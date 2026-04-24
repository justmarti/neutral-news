//
//  StoryFeedView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/28/26.
//

import SwiftUI

struct StoryFeedView: View {
    let newsItems: [NeutralNews]
    let initialNewsID: String?
    let topContentInset: CGFloat
    let collapsedSheetHeight: CGFloat
    let isArticleExpanded: Bool
    let relatedNewsProvider: (NeutralNews) -> [News]
    let regionProvider: (NeutralNews) -> ContentRegion?
    let onCurrentStoryChange: (NeutralNews, [News], ContentRegion?) -> Void
    let onCollectionEnd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var currentIndex = 0
    @State private var previousNewsIDs: [String] = []
    @State private var prefetchTask: Task<Void, Never>?

    init(
        newsItems: [NeutralNews],
        initialNewsID: String? = nil,
        topContentInset: CGFloat,
        collapsedSheetHeight: CGFloat,
        isArticleExpanded: Bool,
        relatedNewsProvider: @escaping (NeutralNews) -> [News],
        regionProvider: @escaping (NeutralNews) -> ContentRegion?,
        onCurrentStoryChange: @escaping (NeutralNews, [News], ContentRegion?) -> Void,
        onCollectionEnd: @escaping () -> Void
    ) {
        self.newsItems = newsItems
        self.initialNewsID = initialNewsID
        self.topContentInset = topContentInset
        self.collapsedSheetHeight = collapsedSheetHeight
        self.isArticleExpanded = isArticleExpanded
        self.relatedNewsProvider = relatedNewsProvider
        self.regionProvider = regionProvider
        self.onCurrentStoryChange = onCurrentStoryChange
        self.onCollectionEnd = onCollectionEnd

        let initialIndex = initialNewsID.flatMap { selectedNewsID in
            newsItems.firstIndex(where: { $0.id == selectedNewsID })
        } ?? 0

        _currentIndex = State(initialValue: initialIndex)
        _previousNewsIDs = State(initialValue: newsItems.map(\.id))
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let reservedSheetHeight = collapsedReservedHeight(
                bottomInset: geometry.safeAreaInsets.bottom
            )

            ZStack(alignment: .top) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(newsItems.enumerated()), id: \.element.id) { index, news in
                        StoryPageView(
                            news: news,
                            onGoPrevious: {
                                moveToPreviousStory()
                            },
                            onGoNext: {
                                moveToNextStory()
                            },
                            canGoPrevious: index > 0,
                            canGoNext: !newsItems.isEmpty,
                            nextAccessibilityLabel: index < newsItems.count - 1 ? "Next story" : "Close stories",
                            reservedBottomHeight: reservedSheetHeight
                        )
                        .frame(width: size.width, height: size.height)
                        .tag(index)
                    }
                }
                .frame(width: size.width, height: size.height)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Color.clear)
                .ignoresSafeArea()

                if newsItems.count > 1, !isArticleExpanded {
                    StoryProgressView(
                        totalCount: newsItems.count,
                        currentIndex: currentIndex
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, topContentInset)
                    .zIndex(2)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea()
        .onAppear {
            syncCurrentIndex(with: newsItems.map(\.id))
            notifyCurrentStoryChange()
            triggerPrefetch()
        }
        .onChange(of: newsItems.map(\.id)) { _, newIDs in
            syncCurrentIndex(with: newIDs)
            notifyCurrentStoryChange()
            triggerPrefetch()
        }
        .onChange(of: currentIndex) { _, _ in
            notifyCurrentStoryChange()
            triggerPrefetch()
        }
        .onDisappear {
            prefetchTask?.cancel()
            prefetchTask = nil
        }
    }

    private func moveToPreviousStory() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    private func moveToNextStory() {
        guard !newsItems.isEmpty else { return }

        if currentIndex < newsItems.count - 1 {
            currentIndex += 1
        } else {
            onCollectionEnd()
        }
    }

    private func syncCurrentIndex(with newIDs: [String]) {
        let adjustedIndex = StoryFeedState.adjustedIndex(
            currentIndex: currentIndex,
            previousIDs: previousNewsIDs,
            newIDs: newIDs
        )

        let updateIndex = {
            currentIndex = adjustedIndex
        }

        if accessibilityReduceMotion {
            updateIndex()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                updateIndex()
            }
        }

        previousNewsIDs = newIDs
    }

    private func triggerPrefetch() {
        guard newsItems.indices.contains(currentIndex) else { return }

        prefetchTask?.cancel()
        prefetchTask = Task(priority: .utility) {
            await prefetchUpcomingImages()
        }
    }

    private func prefetchUpcomingImages() async {
        let upcomingURLs = newsItems
            .dropFirst(currentIndex + 1)
            .prefix(3)
            .compactMap { URL(string: $0.imageUrl) }

        await CachedAsyncImageHelper.prefetchImages(from: Array(upcomingURLs))
    }

    private func notifyCurrentStoryChange() {
        guard newsItems.indices.contains(currentIndex) else { return }

        let currentNews = newsItems[currentIndex]
        onCurrentStoryChange(
            currentNews,
            relatedNewsProvider(currentNews),
            regionProvider(currentNews)
        )
    }

    private func collapsedReservedHeight(bottomInset: CGFloat) -> CGFloat {
        collapsedSheetHeight + bottomInset + 28
    }
}
