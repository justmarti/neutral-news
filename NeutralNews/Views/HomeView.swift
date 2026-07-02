//
//  HomeView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI
import UIKit

struct StoryCollection: Identifiable, Hashable {
    let coverNews: NeutralNews
    let items: [NeutralNews]

    let id = "briefing"
}

struct StoryArticleNavigationTarget: Identifiable, Hashable {
    let news: NeutralNews
    let relatedNews: [News]
    let region: ContentRegion?

    var id: String { news.id }
}

enum StoryCollectionBuilder {
    private static let briefingLimit = 8
    private static let briefingWindow: TimeInterval = 24 * 60 * 60

    static func buildBriefingCollection(
        news: [NeutralNews],
        referenceDate: Date = .now
    ) -> StoryCollection? {
        let windowStart = referenceDate.addingTimeInterval(-briefingWindow)
        let relevantItems = Array(
            news
                .filter { $0.date >= windowStart }
                .sorted { first, second in
                    if first.relevance != second.relevance {
                        return first.relevance > second.relevance
                    }

                    if first.date != second.date {
                        return first.date > second.date
                    }

                    return first.id < second.id
                }
                .prefix(briefingLimit)
        )
        let briefingItems = relevantItems.sorted { first, second in
            if first.date != second.date {
                return first.date > second.date
            }

            if first.relevance != second.relevance {
                return first.relevance > second.relevance
            }

            return first.id < second.id
        }

        guard let coverNews = briefingItems.first else {
            return nil
        }

        return StoryCollection(
            coverNews: coverNews,
            items: briefingItems
        )
    }
}

struct HomeView: View {
    @State private var vm = NewsListViewModel.shared
    @State private var newsDataManager = NewsDataManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("isBackgroundColorEnabled") private var isBackgroundColorEnabled = true
    @AppStorage("viewedStoryCollectionKeys") private var viewedStoryCollectionKeysStorage = ""
    @State private var targetNews: NewsListViewModel.DeepLinkNavigationTarget?
    @State private var storyArticleTarget: StoryArticleNavigationTarget?
    @State private var isStoryOverlayHiddenForArticle = false
    @State private var showingPaywall = false
    @State private var showingSettingsSheet = false
    @State private var storyPresentation: StoryCollection?
    @State private var storyInitialNewsID: String?
    @State private var isStoryArticleExpanded = false
    @State private var isSearchPresented = false
    @State private var currentStoryOverlayNews: NeutralNews?
    @State private var currentStoryOverlayRelatedNews: [News] = []
    @State private var currentStoryOverlayRegion: ContentRegion?
    @State private var homeScreenQuickActionService = HomeScreenQuickActionService.shared
    @State private var savedNewsState = SavedNewsState.shared
    @State private var foregroundRefreshTask: Task<Void, Never>?
    @State private var homeScreenQuickActionTask: Task<Void, Never>?
    @State private var shouldShowPaywallAfterSettingsDismiss = false
#if DEBUG
    @State private var shouldShowDebugOnboardingAfterSettingsDismiss = false
#endif
    private let pushNotificationService = PushNotificationService.shared

    @Namespace private var animationNamespace
    var config: AppConfig

    // Premium manager for UI state
    private let premiumManager = PremiumManager.shared

    // MARK: - Computed Properties

    private var shouldShowPremiumBanner: Bool {
        vm.searchScope == .lastSevenDays && !premiumManager.isPremium
    }

    private var navigationTitleText: String {
        if vm.isShowingSavedNews {
            return String(localized: "Saved News")
        } else if vm.isShowingAllDays {
            return String(localized: "All News")
        } else {
            return vm.daySelected.dayName
        }
    }

    private var navigationSubtitleText: String {
        if vm.isShowingSavedNews {
            return String(localized: vm.savedNewsSubtitle)
        } else if vm.isShowingAllDays {
            return String(localized: "Last 7 days")
        } else {
            return vm.daySelected.formattedDateShort
        }
    }

    private var onboardingPresentation: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { _ in }
        )
    }

    private var shouldShowStoryBriefing: Bool {
        !vm.isShowingSavedNews
            && vm.searchText.isEmpty
            && !vm.isAnyFilterEnabled
            && (isShowingTodayHome || vm.isShowingAllDays)
    }

    private var isShowingTodayHome: Bool {
        Calendar.current.isDateInToday(vm.daySelected.date)
            && !vm.isShowingAllDays
            && vm.searchScope == .daySelected
    }

    private var briefingCollection: StoryCollection? {
        guard shouldShowStoryBriefing else { return nil }

        let recentNews = vm.isShowingAllDays
            ? newsDataManager.neutralNews
            : newsDataManager.getNewsArrayForDay(.today) + previousDayNewsForStoryWindow

        return StoryCollectionBuilder.buildBriefingCollection(news: recentNews)
    }

    private var previousDayForStoryWindow: DayInfo? {
        Calendar.current.date(byAdding: .day, value: -1, to: DayInfo.today.date)
            .map(DayInfo.init)
    }

    private var previousDayNewsForStoryWindow: [NeutralNews] {
        guard let previousDayForStoryWindow else { return [] }
        return newsDataManager.getNewsArrayForDay(previousDayForStoryWindow)
    }

    var body: some View {
        let relatedNewsRefreshToken = newsDataManager.allNews.count

        ZStack {
            Group {
                if config.isInMaintenance {
                    MaintenanceView(config: config)
                } else {
                    NavigationStack {
                        navigationContent(relatedNewsRefreshToken: relatedNewsRefreshToken)
                    }
                    .allowsHitTesting(storyPresentation == nil || isStoryOverlayHiddenForArticle)
                    .fullScreenCover(isPresented: onboardingPresentation) {
                        OnboardingView(onComplete: handleOnboardingCompletion)
                    }
                    .onChange(of: vm.deepLinkTargetNews) { oldValue, newValue in
                        if let target = newValue {
#if DEBUG
                            print("🎯 View received target news: \(target.news.neutralTitle)")
#endif
                            targetNews = target

                            Task {
                                try? await Task.sleep(nanoseconds: 100_000_000)
                                vm.deepLinkTargetNews = nil
                            }
                        }
                    }
                    .onAppear {
                        vm.checkPendingDeepLink()
                        handlePendingHomeScreenQuickAction()
                    }
                    .task(id: shouldShowStoryBriefing) {
                        await loadStoryWindowNewsIfNeeded()
                    }
                    .onChange(of: homeScreenQuickActionService.pendingAction) { _, _ in
                        handlePendingHomeScreenQuickAction()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: PushNotificationService.didReceiveDeepLinkNotification)) { notification in
                        guard let deepLink = notification.userInfo?[PushNotificationService.deepLinkUserInfoKey] as? DeepLinkService.DeepLinkData else {
                            return
                        }

                        vm.isLoadingNeutralNews = true
                        vm.handleDeepLink(deepLink)
                    }
                    .onChange(of: scenePhase) { oldValue, newValue in
                        guard oldValue == .background, newValue == .active else { return }
                        refreshNewsAfterForegroundEvent()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                        refreshNewsAfterForegroundEvent()
                    }
                    .onChange(of: premiumManager.paywallPresentationToken) { _, _ in
                        showingPaywall = true
                    }
                    .onChange(of: storyArticleTarget) { _, newValue in
                        if newValue == nil {
                            isStoryOverlayHiddenForArticle = false
                        }
                    }
                    .sheet(isPresented: $showingPaywall) {
                        PaywallView(isPresented: $showingPaywall)
                    }
                    .sheet(isPresented: $showingSettingsSheet) {
#if DEBUG
                        SettingsView(
                            vm: vm,
                            systemColorScheme: colorScheme,
                            showPaywall: {
                                shouldShowPaywallAfterSettingsDismiss = true
                            },
                            showDebugOnboarding: {
                                shouldShowDebugOnboardingAfterSettingsDismiss = true
                            }
                        )
#else
                        SettingsView(
                            vm: vm,
                            systemColorScheme: colorScheme,
                            showPaywall: {
                                shouldShowPaywallAfterSettingsDismiss = true
                            }
                        )
#endif
                    }
                    .onChange(of: showingSettingsSheet) { _, isPresented in
                        guard !isPresented else { return }

                        if shouldShowPaywallAfterSettingsDismiss {
                            shouldShowPaywallAfterSettingsDismiss = false
                            showingPaywall = true
                        }

#if DEBUG
                        if shouldShowDebugOnboardingAfterSettingsDismiss {
                            shouldShowDebugOnboardingAfterSettingsDismiss = false
                            showDebugOnboarding()
                        }
#endif
                    }
                }
            }

            if let story = storyPresentation, !isStoryOverlayHiddenForArticle {
                storyReaderView(for: story)
                    .zIndex(1)
            }

            if storyPresentation == nil || isStoryOverlayHiddenForArticle {
                AppFeedbackOverlay()
                    .zIndex(2)
            }
        }
        .animation(.default, value: config.isInMaintenance)
    }
    
    // MARK: - Content Views

    @ViewBuilder
    private func navigationContent(relatedNewsRefreshToken: Int) -> some View {
        let baseContent = newsContentView
            .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
            .animation(.default, value: vm.isShowingSavedNews)
            .animation(.default, value: relatedNewsRefreshToken)
            .navigationDestination(item: $targetNews) { target in
                NeutralNewsView(
                    news: target.news,
                    relatedNews: target.relatedNews,
                    region: target.region,
                    namespace: animationNamespace
                )
                    .toolbarVisibility(.visible, for: .navigationBar)
                    .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
                    .onAppear {
                        RatingManager.shared.incrementNewsReadCount()
                        RatingManager.shared.requestRatingAfterPositiveInteraction()

                        if hasSeenOnboarding {
                            pushNotificationService.handleOpenedArticle()
                        }
                    }
            }
            .navigationDestination(item: $storyArticleTarget) { target in
                NeutralNewsView(
                    news: target.news,
                    relatedNews: target.relatedNews,
                    region: target.region,
                    namespace: animationNamespace
                )
                    .toolbarVisibility(.visible, for: .navigationBar)
                    .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
            }

        baseContent
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.large)
            .myNavigationSubtitle(navigationSubtitleText)
            .searchable(text: $vm.searchText, isPresented: $isSearchPresented, placement: .toolbar, prompt: "Search")
            .searchScopes(vm.isShowingSavedNews ? .constant(.daySelected) : (vm.isShowingAllDays ? .constant(.lastSevenDays) : $vm.searchScope)) {
                if !vm.isShowingAllDays && !vm.isShowingSavedNews {
                    Text(vm.daySelected.dayName).tag(SearchScope.daySelected)
                    Text("Last 7 days").tag(SearchScope.lastSevenDays)
                }
            }
            .toolbar {
                HomeToolbar(
                    vm: vm,
                    showingSettings: $showingSettingsSheet
                ).content
            }
            .accentGradientBackground(isEnabled: isBackgroundColorEnabled)
            .onChange(of: isSearchPresented) { oldValue, newValue in
                guard oldValue && !newValue else { return }

                if vm.searchScope == .lastSevenDays {
                    vm.searchScope = .daySelected
                }
            }
    }
    
    private var newsContentView: some View {
        let currentNews = vm.newsToShow

        return GeometryReader { geometry in
            ScrollView {
                contentStateView(
                    newsItems: currentNews,
                    availableSize: geometry.size
                )
            }
            .scrollIndicators(.automatic)
            .scrollBounceBehavior(.basedOnSize)
            .refreshable {
                if vm.isShowingSavedNews {
                    await vm.loadSavedNews()
                } else {
                    await vm.refreshNews()
                }
            }
        }
    }

    @ViewBuilder
    private func contentStateView(
        newsItems: [NeutralNews],
        availableSize: CGSize
    ) -> some View {
        if vm.isShowingSavedNews {
            savedNewsContentView(
                newsItems: newsItems,
                availableSize: availableSize
            )
        } else if vm.pendingDeepLink != nil {
            // Show loading while processing deep link
            loadingView
        } else if vm.isLoadingNeutralNews && newsItems.isEmpty {
            loadingView
        } else if !vm.searchText.isEmpty && newsItems.isEmpty && !vm.isLoadingNeutralNews && !vm.isLoadingForSearch {
            noResultsView
        } else if vm.searchText.isEmpty && newsItems.isEmpty && !vm.isLoadingNeutralNews && vm.hasCompletedInitialLaunchLoad {
            noNewsYetView
        } else {
            newsRendererView(
                newsItems: newsItems,
                availableSize: availableSize
            )
        }
    }

    @ViewBuilder
    private func newsRendererView(
        newsItems: [NeutralNews],
        availableSize: CGSize
    ) -> some View {
        newsListView(newsItems: newsItems)
    }
    
    private func newsListView(newsItems: [NeutralNews]) -> some View {
        VStack(spacing: 0) {
            if let briefingCollection {
                StoryBriefingModuleView(collection: briefingCollection) {
                    selectedNews in
                    presentStories(briefingCollection, initialNewsID: selectedNews.id)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }

            LazyVStack {
                // Premium search results banner
                if shouldShowPremiumBanner {
                    premiumSearchBanner
                }

                // Loading indicator for search across 7 days (free users)
                if vm.isLoadingForSearch {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.vertical)
                }

                ForEach(newsItems) { neutralNews in
                    HomeNewsCard(
                        news: neutralNews,
                        relatedNews: vm.getRelatedNews(from: neutralNews),
                        namespace: animationNamespace,
                        isBackgroundColorEnabled: isBackgroundColorEnabled,
                        vm: vm,
                        premiumManager: premiumManager,
                        savedNewsState: savedNewsState
                    )
                }
                .animation(.default, value: newsItems)

                // Loading indicator for pagination
                if vm.isLoadingMore {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more news...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }

    private var noResultsView: some View {
        ContentUnavailableView(
            vm.isShowingAllDays || vm.searchScope == .lastSevenDays
                ? "No results for \"\(vm.searchText)\""
                : "No results for \"\(vm.searchText)\" in news from \(vm.daySelected.dayName)",
            systemImage: "magnifyingglass",
            description: Text(vm.isShowingAllDays || vm.searchScope == .lastSevenDays
                ? "Try another search term."
                : "Try another term or select a different day.")
        )
        .containerRelativeFrame([.horizontal, .vertical])
    }
    
    private var noNewsYetView: some View {
        ContentUnavailableView(
            "No news yet",
            systemImage: "newspaper",
            description: Text(vm.isShowingAllDays || vm.searchScope == .lastSevenDays
                ? "Try again in a few minutes."
                : "Try again later or select another day.")
        )
        .containerRelativeFrame([.horizontal, .vertical])
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading news...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .containerRelativeFrame([.horizontal, .vertical])
    }

    private func savedNewsContentView(
        newsItems: [NeutralNews],
        availableSize: CGSize
    ) -> some View {
        Group {
            if vm.isLoadingSavedNews {
                ProgressView("Loading saved news...")
                    .frame(width: availableSize.width)
                    .frame(minHeight: availableSize.height)
            } else if !vm.searchText.isEmpty && newsItems.isEmpty {
                ContentUnavailableView(
                    "No results for \"\(vm.searchText)\"",
                    systemImage: "magnifyingglass",
                    description: Text("Try another search in your saved news.")
                )
                .frame(width: availableSize.width)
                .frame(minHeight: availableSize.height)
            } else if vm.savedNews.isEmpty {
                ContentUnavailableView(
                    "You don't have any saved news",
                    systemImage: "bookmark.slash",
                    description: Text("Save stories you're interested in to read later.")
                )
                .frame(width: availableSize.width)
                .frame(minHeight: availableSize.height)
            } else {
                newsRendererView(
                    newsItems: newsItems,
                    availableSize: availableSize
                )
            }
        }
    }

    private var premiumSearchBanner: some View {
        Button {
            showingPaywall.toggle()
        } label: {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(.accent.gradient)
                
                VStack(alignment: .leading) {
                    Text("Top results")
                        .font(.headline)
                    
                    Text("Access all results with Facts Pro")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(.accent.quinary.opacity(0.5), in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleOnboardingCompletion() {
        hasSeenOnboarding = true
        pushNotificationService.handleCompletedOnboarding()
        showingPaywall = true
    }

#if DEBUG
    private func showDebugOnboarding() {
        hasSeenOnboarding = false
    }
#endif

    private func presentStories(_ collection: StoryCollection, initialNewsID: String? = nil) {
        let presentedCollection = reorderedStoryCollection(from: collection, startingAt: initialNewsID)
        let initialNews = presentedCollection.coverNews

        storyInitialNewsID = initialNews.id
        isStoryArticleExpanded = false
        currentStoryOverlayNews = initialNews
        currentStoryOverlayRelatedNews = vm.getRelatedNews(from: initialNews)
        currentStoryOverlayRegion = resolvedRegion(for: initialNews)
        storyPresentation = presentedCollection
    }

    private func reorderedStoryCollection(
        from collection: StoryCollection,
        startingAt initialNewsID: String?
    ) -> StoryCollection {
        guard let initialNewsID,
              let selectedIndex = collection.items.firstIndex(where: { $0.id == initialNewsID }),
              selectedIndex > 0 else {
            return collection
        }

        let reorderedItems = Array(collection.items[selectedIndex...])
            + Array(collection.items[..<selectedIndex])

        guard let reorderedCoverNews = reorderedItems.first else {
            return collection
        }

        return StoryCollection(
            coverNews: reorderedCoverNews,
            items: reorderedItems
        )
    }

    private func resetStoryPresentationState() {
        storyPresentation = nil
        storyInitialNewsID = nil
        storyArticleTarget = nil
        isStoryOverlayHiddenForArticle = false
        isStoryArticleExpanded = false
        currentStoryOverlayNews = nil
        currentStoryOverlayRelatedNews = []
        currentStoryOverlayRegion = nil
    }

    private func storyReaderView(for collection: StoryCollection) -> some View {
        StoryReaderModalView(
            collection: collection,
            initialNewsID: currentStoryOverlayNews?.id ?? storyInitialNewsID ?? collection.coverNews.id,
            accessibilityReduceMotion: accessibilityReduceMotion,
            currentStoryOverlayNews: $currentStoryOverlayNews,
            currentStoryOverlayRelatedNews: $currentStoryOverlayRelatedNews,
            currentStoryOverlayRegion: $currentStoryOverlayRegion,
            isStoryArticleExpanded: $isStoryArticleExpanded,
            relatedNewsProvider: { news in
                vm.getRelatedNews(from: news)
            },
            regionProvider: { news in
                resolvedRegion(for: news)
            },
            onDismissCollection: { completed in
                if completed {
                    markStoryCollectionAsViewed(collection)
                }
            },
            onOpenArticle: { news, relatedNews, region in
                openStoryArticle(news, relatedNews: relatedNews, region: region)
            },
            onCloseStory: {
                resetStoryPresentationState()
            }
        )
    }

    private func openStoryArticle(
        _ news: NeutralNews,
        relatedNews: [News],
        region: ContentRegion?
    ) {
        storyInitialNewsID = news.id
        isStoryOverlayHiddenForArticle = true
        storyArticleTarget = StoryArticleNavigationTarget(
            news: news,
            relatedNews: relatedNews,
            region: region ?? ContentRegionProvider().currentRegion
        )
    }

    private var viewedStoryCollectionKeys: Set<String> {
        Set(
            viewedStoryCollectionKeysStorage
                .split(separator: "\n")
                .map(String.init)
        )
    }

    private func storyCollectionKey(for collection: StoryCollection) -> String {
        let itemIDsKey = collection.items.map(\.id).joined(separator: ",")
        return "\(collection.id)|\(itemIDsKey)"
    }

    private func markStoryCollectionAsViewed(_ collection: StoryCollection) {
        var updatedKeys = viewedStoryCollectionKeys
        updatedKeys.insert(storyCollectionKey(for: collection))
        viewedStoryCollectionKeysStorage = updatedKeys.sorted().joined(separator: "\n")
    }

    private func loadStoryWindowNewsIfNeeded() async {
        guard shouldShowStoryBriefing,
              let previousDayForStoryWindow,
              !newsDataManager.isDayLoaded(previousDayForStoryWindow) else {
            return
        }

        await newsDataManager.loadNews(for: previousDayForStoryWindow)
    }

    private func refreshNewsAfterForegroundEvent() {
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = Task {
            guard !Task.isCancelled else { return }

            if vm.isShowingSavedNews {
                await vm.loadSavedNews()
            } else {
                await vm.refreshNewsForCurrentDateIfNeeded()
            }
        }
    }

    private func handlePendingHomeScreenQuickAction() {
        guard let action = HomeScreenQuickActionService.shared.consumePendingAction() else { return }
        handleHomeScreenQuickAction(action)
    }

    private func handleHomeScreenQuickAction(_ action: HomeScreenQuickAction) {
        resetStoryPresentationState()

        switch action {
        case .search:
            presentSearchFromHomeScreen()
        case .savedNews:
            presentSavedNewsFromHomeScreen()
        case .randomNews:
            openRandomNewsFromHomeScreen()
        }
    }

    private func presentSearchFromHomeScreen() {
        if vm.isShowingSavedNews {
            vm.toggleSavedNewsMode()
        } else {
            vm.clearFilters()
        }

        isSearchPresented = true
    }

    private func presentSavedNewsFromHomeScreen() {
        if !vm.isShowingSavedNews {
            vm.toggleSavedNewsMode()
        } else {
            vm.clearFilters()
        }

        isSearchPresented = false
    }

    private func openRandomNewsFromHomeScreen() {
        homeScreenQuickActionTask?.cancel()
        homeScreenQuickActionTask = Task {
            if vm.isShowingSavedNews {
                vm.toggleSavedNewsMode()
            } else {
                vm.clearFilters()
            }

            await waitForInitialNewsLoadIfNeeded()

            guard !Task.isCancelled,
                  let news = vm.newsToShow.randomElement()
            else { return }

            targetNews = NewsListViewModel.DeepLinkNavigationTarget(
                news: news,
                relatedNews: vm.getRelatedNews(from: news),
                region: ContentRegionProvider().currentRegion
            )
        }
    }

    private func waitForInitialNewsLoadIfNeeded() async {
        var attempts = 0

        while !vm.hasCompletedInitialLaunchLoad && attempts < 40 {
            try? await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
    }

    private func resolvedRegion(for news: NeutralNews) -> ContentRegion? {
        guard let regionRaw = vm.savedRegionRaw(for: news.id) else {
            return nil
        }

        return ContentRegion(rawValue: regionRaw)
    }
}

private struct StoryReaderModalView: View {
    let collection: StoryCollection
    let initialNewsID: String
    let accessibilityReduceMotion: Bool
    @Binding var currentStoryOverlayNews: NeutralNews?
    @Binding var currentStoryOverlayRelatedNews: [News]
    @Binding var currentStoryOverlayRegion: ContentRegion?
    @Binding var isStoryArticleExpanded: Bool
    let relatedNewsProvider: (NeutralNews) -> [News]
    let regionProvider: (NeutralNews) -> ContentRegion?
    let onDismissCollection: (Bool) -> Void
    let onOpenArticle: (NeutralNews, [News], ContentRegion?) -> Void
    let onCloseStory: () -> Void

    @State private var isInteractiveDismissInFlight = false
    @State private var isArticleSheetPresented = true
    @State private var sheetNews: NeutralNews
    @State private var collapsedSheetHeight: CGFloat
    @State private var reservedFeedBottomHeight: CGFloat
    @State private var selectedSheetDetent: PresentationDetent
    @State private var pendingStoryDismissCompletion: Bool?
    @State private var shareSheetItem: StoryShareSheetItem?
    @State private var surfaceOffsetY: CGFloat = 24
    @State private var surfaceOpacity: Double = 0
    @State private var backdropVisibility: Double = 0

    init(
        collection: StoryCollection,
        initialNewsID: String,
        accessibilityReduceMotion: Bool,
        currentStoryOverlayNews: Binding<NeutralNews?>,
        currentStoryOverlayRelatedNews: Binding<[News]>,
        currentStoryOverlayRegion: Binding<ContentRegion?>,
        isStoryArticleExpanded: Binding<Bool>,
        relatedNewsProvider: @escaping (NeutralNews) -> [News],
        regionProvider: @escaping (NeutralNews) -> ContentRegion?,
        onDismissCollection: @escaping (Bool) -> Void,
        onOpenArticle: @escaping (NeutralNews, [News], ContentRegion?) -> Void,
        onCloseStory: @escaping () -> Void
    ) {
        self.collection = collection
        self.initialNewsID = initialNewsID
        self.accessibilityReduceMotion = accessibilityReduceMotion
        self._currentStoryOverlayNews = currentStoryOverlayNews
        self._currentStoryOverlayRelatedNews = currentStoryOverlayRelatedNews
        self._currentStoryOverlayRegion = currentStoryOverlayRegion
        self._isStoryArticleExpanded = isStoryArticleExpanded
        self.relatedNewsProvider = relatedNewsProvider
        self.regionProvider = regionProvider
        self.onDismissCollection = onDismissCollection
        self.onOpenArticle = onOpenArticle
        self.onCloseStory = onCloseStory

        let initialSheetNews = collection.items.first(where: { $0.id == initialNewsID }) ?? collection.coverNews
        let initialCollapsedHeight = StoryArticleSheetView.estimatedCollapsedHeight(for: initialSheetNews)
        _sheetNews = State(initialValue: initialSheetNews)
        _collapsedSheetHeight = State(initialValue: initialCollapsedHeight)
        _reservedFeedBottomHeight = State(initialValue: StoryArticleSheetView.stableReservedHeight(for: initialSheetNews))
        _selectedSheetDetent = State(initialValue: .height(initialCollapsedHeight))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(backdropVisibility)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ZStack(alignment: .top) {
                    StoryFeedView(
                        newsItems: collection.items,
                        initialNewsID: initialNewsID,
                        topContentInset: geometry.safeAreaInsets.top + 10,
                        collapsedSheetHeight: reservedFeedBottomHeight,
                        isArticleExpanded: isStoryArticleExpanded,
                        relatedNewsProvider: relatedNewsProvider,
                        regionProvider: regionProvider,
                        onCurrentStoryChange: { news, relatedNews, region in
                            sheetNews = news
                            if selectedSheetDetent != .large {
                                let estimatedHeight = StoryArticleSheetView.estimatedCollapsedHeight(for: news)
                                collapsedSheetHeight = estimatedHeight
                                selectedSheetDetent = .height(estimatedHeight)
                            }
                            currentStoryOverlayNews = news
                            currentStoryOverlayRelatedNews = relatedNews
                            currentStoryOverlayRegion = region
                        },
                        onCollectionEnd: {
                            dismissStory(completed: true)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()

                    if !isStoryArticleExpanded {
                        StoryHomeOverlayView(
                            currentNews: currentStoryOverlayNews,
                            currentRelatedNews: currentStoryOverlayRelatedNews,
                            currentRegion: currentStoryOverlayRegion,
                            onShare: { url in
                                shareSheetItem = StoryShareSheetItem(url: url)
                            },
                            onClose: {
                                dismissStory(completed: isCurrentStoryLastInCollection)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, geometry.safeAreaInsets.top + 24)
                        .transition(.opacity)
                    }

                    AppFeedbackOverlay(
                        placement: .top,
                        edgePadding: geometry.safeAreaInsets.top + 84
                    )
                    .zIndex(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: surfaceOffsetY)
                .opacity(surfaceOpacity)
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $isArticleSheetPresented, onDismiss: handleArticleSheetDismiss) {
            StoryArticleSheetView(
                news: sheetNews,
                selectedDetent: $selectedSheetDetent,
                collapsedHeight: $collapsedSheetHeight,
                visualOffset: surfaceOffsetY,
                visualOpacity: surfaceOpacity,
                onOpenArticle: {
                    onOpenArticle(
                        sheetNews,
                        currentStoryOverlayRelatedNews,
                        currentStoryOverlayRegion
                    )
                }
            )
            .id(sheetNews.id)
            .presentationDetents([collapsedSheetDetent, .large], selection: $selectedSheetDetent)
            .presentationContentInteraction(.scrolls)
            .presentationBackgroundInteraction(.enabled(upThrough: collapsedSheetDetent))
            .presentationBackground(.clear)
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
            .sheet(item: $shareSheetItem) { item in
                StoryShareSheetView(item: item)
            }
        }
        .onChange(of: selectedSheetDetent) { _, newValue in
            let isExpanded = newValue == .large
            if accessibilityReduceMotion {
                isStoryArticleExpanded = isExpanded
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isStoryArticleExpanded = isExpanded
                }
            }
        }
        .onDisappear {
            pendingStoryDismissCompletion = nil
        }
        .onAppear(perform: animateStoryIn)
    }

    private var isCurrentStoryLastInCollection: Bool {
        guard let lastStoryID = collection.items.last?.id else {
            return false
        }

        return currentStoryOverlayNews?.id == lastStoryID
    }

    private func dismissStory(completed: Bool) {
        guard !isInteractiveDismissInFlight else { return }

        isInteractiveDismissInFlight = true

        if accessibilityReduceMotion {
            surfaceOffsetY = 24
            surfaceOpacity = 0
            backdropVisibility = 0
            beginStoryDismiss(completed: completed)
            return
        }

        withAnimation(
            .easeInOut(duration: 0.2),
            completionCriteria: .logicallyComplete
        ) {
            surfaceOffsetY = 24
            surfaceOpacity = 0
            backdropVisibility = 0
        } completion: {
            beginStoryDismiss(completed: completed)
        }
    }

    private var collapsedSheetDetent: PresentationDetent {
        .height(collapsedSheetHeight)
    }

    private func beginStoryDismiss(completed: Bool) {
        guard pendingStoryDismissCompletion == nil else { return }

        pendingStoryDismissCompletion = completed

        if isArticleSheetPresented {
            isArticleSheetPresented = false
        } else {
            finishStoryDismiss(completed: completed)
        }
    }

    private func finishStoryDismiss(completed: Bool) {
        pendingStoryDismissCompletion = nil
        isArticleSheetPresented = false
        isStoryArticleExpanded = false
        isInteractiveDismissInFlight = false
        onDismissCollection(completed)
        onCloseStory()
    }

    private func handleArticleSheetDismiss() {
        isStoryArticleExpanded = false
        isInteractiveDismissInFlight = false

        guard let completed = pendingStoryDismissCompletion else {
            onCloseStory()
            return
        }

        finishStoryDismiss(completed: completed)
    }

    private func animateStoryIn() {
        guard !accessibilityReduceMotion else {
            surfaceOffsetY = 0
            surfaceOpacity = 1
            backdropVisibility = 1
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            surfaceOffsetY = 0
            surfaceOpacity = 1
            backdropVisibility = 1
        }
    }
}

private struct StoryShareSheetItem: Identifiable, Equatable {
    let url: URL

    var id: String {
        url.absoluteString
    }
}

private struct StoryShareSheetView: UIViewControllerRepresentable {
    let item: StoryShareSheetItem

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [item.url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - View Extensions

extension View {
    func accentGradientBackground(isEnabled: Bool) -> some View {
        modifier(AccentGradientBackground(isEnabled: isEnabled))
    }

    @ViewBuilder
    func myNavigationSubtitle(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *), !subtitle.isEmpty {
            self.navigationSubtitle(subtitle)
        } else {
            self
        }
    }

}

// MARK: - Environment Keys

private struct BackgroundColorEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isBackgroundColorEnabled: Bool {
        get { self[BackgroundColorEnabledKey.self] }
        set { self[BackgroundColorEnabledKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func myToolbar() -> some View {
        if #available(iOS 26.0, *) {
            self.toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
        } else { self }
    }
}

#Preview {
    HomeView(config: AppConfig(isTestMode: true))
}

private struct HomeNewsCard: View {
    let news: NeutralNews
    let relatedNews: [News]
    let namespace: Namespace.ID
    let isBackgroundColorEnabled: Bool
    let vm: NewsListViewModel
    let premiumManager: PremiumManager
    let savedNewsState: SavedNewsState

    init(
        news: NeutralNews,
        relatedNews: [News],
        namespace: Namespace.ID,
        isBackgroundColorEnabled: Bool,
        vm: NewsListViewModel,
        premiumManager: PremiumManager,
        savedNewsState: SavedNewsState
    ) {
        self.news = news
        self.relatedNews = relatedNews
        self.namespace = namespace
        self.isBackgroundColorEnabled = isBackgroundColorEnabled
        self.vm = vm
        self.premiumManager = premiumManager
        self.savedNewsState = savedNewsState
    }

    var body: some View {
        NavigationLink {
            NeutralNewsView(news: news, relatedNews: relatedNews, region: nil, namespace: namespace)
                .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
                .navigationTransition(.zoom(sourceID: news.id, in: namespace))
                .onAppear {
                    RatingManager.shared.incrementNewsReadCount()
                    RatingManager.shared.requestRatingAfterPositiveInteraction()
                }
        } label: {
            NewsImageView(news: news, imageUrl: news.imageUrl)
                .padding(.vertical, 4)
                .matchedTransitionSource(id: news.id, in: namespace)
        }
        .buttonStyle(.plain)
        .contextMenu {
            let saved = currentSavedStatus
            Button {
                handleSaveAction()
            } label: {
                Label(
                    saved ? "Saved" : "Save",
                    systemImage: !premiumManager.canSaveNews
                        ? "lock.fill"
                        : (saved ? "bookmark.fill" : "bookmark")
                )
            }

            ShareLink(item: DeepLinkService.generateShareURL(for: news, region: shareRegion)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                UIPasteboard.general.string = news.neutralTitle
                AppFeedbackCenter.shared.show("Headline copied", systemImage: "doc.on.doc", style: .success)
            } label: {
                Label("Copy headline", systemImage: "doc.on.doc")
            }
        }
        .onAppear {
            if vm.shouldLoadMore(currentItem: news) {
                vm.loadNextPage()
            }
        }
        .task(id: news.id) {
            await ensureSavedStatusLoadedIfNeeded()
        }
    }

    private func handleSaveAction() {
        if premiumManager.canSaveNews {
            Task {
                await toggleSave()
            }
        } else {
            premiumManager.requirePremium(for: "save_news") {
                Task {
                    await toggleSave()
                }
            }
        }
    }

    private func toggleSave() async {
        let context = vm.coreDataContext
        let currentlySaved = currentSavedStatus
        do {
            if currentlySaved {
                let unsaveRegionRaw = vm.isShowingSavedNews ? vm.savedRegionRaw(for: news.id) : nil
                try SavedNewsService.shared.unsaveNews(newsId: news.id, context: context, regionRaw: unsaveRegionRaw)
                await MainActor.run {
                    vm.removeFromSavedNews(news.id)
                    savedNewsState.setSaved(false, for: news.id, regionRaw: unsaveRegionRaw)
                    AppFeedbackCenter.shared.show("Removed from saved", systemImage: "bookmark.slash", style: .info, haptic: .success)
                }
            } else {
                try SavedNewsService.shared.saveNews(
                    news,
                    context: context,
                    relatedNews: relatedNews
                )
                await MainActor.run {
                    savedNewsState.setSaved(true, for: news.id)
                    AppFeedbackCenter.shared.show("Saved", systemImage: "bookmark", style: .success)
                }
            }
        } catch {
            print("❌ Error saving/unsaving article: \(error)")
            await MainActor.run {
                AppFeedbackCenter.shared.show("Couldn’t update saved news", systemImage: "exclamationmark.triangle", style: .error)
            }
        }
    }

    private func ensureSavedStatusLoadedIfNeeded() async {
        guard !vm.isShowingSavedNews else { return }
        guard !savedNewsState.hasStatus(for: news.id) else { return }

        let isSaved = SavedNewsService.shared.isNewsSaved(newsId: news.id, context: vm.coreDataContext)
        await MainActor.run {
            savedNewsState.setSaved(isSaved, for: news.id)
        }
    }

    private var currentSavedStatus: Bool {
        let regionRaw = vm.isShowingSavedNews ? vm.savedRegionRaw(for: news.id) : nil
        return savedNewsState.isSaved(news.id, regionRaw: regionRaw)
    }

    private var shareRegion: ContentRegion {
        if let regionRaw = vm.savedRegionRaw(for: news.id),
           let resolvedRegion = ContentRegion(rawValue: regionRaw) {
            return resolvedRegion
        }

        return ContentRegionProvider().currentRegion
    }
}
