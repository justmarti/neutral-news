//
//  HomeView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI
import UIKit

struct HomeView: View {
    @State private var vm = NewsListViewModel.shared
    @State private var newsDataManager = NewsDataManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("isBackgroundColorEnabled") private var isBackgroundColorEnabled = true
    @State private var targetNews: NeutralNews?
    @State private var showingPaywall = false
    @State private var showingSettingsSheet = false
    @State private var savedNewsState = SavedNewsState.shared
    private let pushNotificationService = PushNotificationService.shared

    @Namespace private var animationNamespace
    @Namespace private var settingsTransitionNamespace
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

    var body: some View {
        let relatedNewsRefreshToken = newsDataManager.allNews.count

        Group {
            if config.isInMaintenance {
                MaintenanceView(config: config)
            } else {
                NavigationStack {
                    newsContentView
                        .navigationTitle(navigationTitleText)
                        // TODO: Mirar que opción es mejor para el title
//                        .toolbarTitleDisplayMode(.inlineLarge)
                        .myNavigationSubtitle(navigationSubtitleText)
                        .searchable(text: $vm.searchText, placement: .toolbar, prompt: "Search")
                        .searchScopes(vm.isShowingSavedNews ? .constant(.daySelected) : (vm.isShowingAllDays ? .constant(.lastSevenDays) : $vm.searchScope), activation: .onSearchPresentation) {
                            if !vm.isShowingAllDays && !vm.isShowingSavedNews {
                                Text(vm.daySelected.dayName).tag(SearchScope.daySelected)
                                Text("Last 7 days").tag(SearchScope.lastSevenDays)
                            }
                        }
                        .toolbar {
                            HomeToolbar(
                                vm: vm,
                                showingSettings: $showingSettingsSheet,
                                settingsTransitionNamespace: settingsTransitionNamespace
                            ).content
                        }
                        .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
                        .animation(.default, value: vm.isShowingSavedNews)
                        .animation(.default, value: relatedNewsRefreshToken)
                        .navigationDestination(item: $targetNews) { news in
                            NeutralNewsView(
                                news: news,
                                relatedNews: vm.getRelatedNews(from: news),
                                namespace: animationNamespace
                            )
                                .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
                                .onAppear {
                                    RatingManager.shared.incrementNewsReadCount()
                                    RatingManager.shared.requestRatingAfterPositiveInteraction()

                                    if hasSeenOnboarding {
                                        pushNotificationService.handleOpenedArticle()
                                    }
                                }
                        }
                        .accentGradientBackground(isEnabled: isBackgroundColorEnabled)
                }
                .fullScreenCover(isPresented: onboardingPresentation) {
                    OnboardingView(onComplete: handleOnboardingCompletion)
                }
                .onChange(of: vm.deepLinkTargetNews) { oldValue, newValue in
                    if let news = newValue {
#if DEBUG
                        print("🎯 View received target news: \(news.neutralTitle)")
#endif
                        targetNews = news
                        
                        // Retrasar limpieza para asegurar navegación
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                            vm.deepLinkTargetNews = nil
                        }
                    }
                }
                .onAppear {
                    vm.checkPendingDeepLink()
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
                    Task {
                        await vm.preloadTodayOnResume()
                    }
                }
                .onChange(of: premiumManager.paywallPresentationToken) { _, _ in
                    showingPaywall = true
                }
                .sheet(isPresented: $showingPaywall) {
                    PaywallView(isPresented: $showingPaywall)
                }
                .sheet(isPresented: $showingSettingsSheet) {
                    SettingsView(
                        vm: vm,
                        systemColorScheme: colorScheme,
                        settingsTransitionNamespace: settingsTransitionNamespace
                    )
                    .presentationDragIndicator(.hidden)
                }
            }
        }
        .animation(.default, value: config.isInMaintenance)
    }
    
    // MARK: - Content Views
    
    private var newsContentView: some View {
        let currentNews = vm.newsToShow

        return ScrollView {
            contentStateView(newsItems: currentNews)
        }
        .refreshable {
            if vm.isShowingSavedNews {
                await vm.loadSavedNews()
            } else {
                await vm.refreshNews()
            }
        }
        .overlay {
            // Hidden child view to access isSearching environment
            SearchableContentView(vm: vm)
        }
    }

    @ViewBuilder
    private func contentStateView(newsItems: [NeutralNews]) -> some View {
        if vm.isShowingSavedNews {
            savedNewsContentView(newsItems: newsItems)
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
            newsListView(newsItems: newsItems)
        }
    }
    
    private func newsListView(newsItems: [NeutralNews]) -> some View {
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

    private func savedNewsContentView(newsItems: [NeutralNews]) -> some View {
        Group {
            if vm.isLoadingSavedNews {
                ProgressView("Loading saved news...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.searchText.isEmpty && newsItems.isEmpty {
                ContentUnavailableView(
                    "No results for \"\(vm.searchText)\"",
                    systemImage: "magnifyingglass",
                    description: Text("Try another search in your saved news.")
                )
                .containerRelativeFrame([.horizontal, .vertical])
            } else if vm.savedNews.isEmpty {
                ContentUnavailableView(
                    "You don't have any saved news",
                    systemImage: "bookmark.slash",
                    description: Text("Save stories you're interested in to read later.")
                )
                .containerRelativeFrame([.horizontal, .vertical])
            } else {
                newsListView(newsItems: newsItems)
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
                    .foregroundStyle(.accent)
                
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
                    .stroke(.quinary, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func handleOnboardingCompletion() {
        hasSeenOnboarding = true
        pushNotificationService.handleCompletedOnboarding()
        showingPaywall = true
    }
}

// MARK: - View Extensions

extension View {
    func accentGradientBackground(isEnabled: Bool) -> some View {
        modifier(AccentGradientBackground(isEnabled: isEnabled))
    }

    @ViewBuilder
    func myNavigationSubtitle(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) { self.navigationSubtitle(subtitle) } else { self }
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
    func mySearchToolbarMinimize() -> some View {
        if #available(iOS 26.0, *) { self.searchToolbarBehavior(.minimize) } else { self }
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
    @State private var saveFeedbackTrigger = 0
    @State private var copyHeadlineTrigger = false

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
            NeutralNewsView(news: news, relatedNews: relatedNews, namespace: namespace)
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
            let saved = vm.isShowingSavedNews ? true : savedNewsState.isSaved(news.id)
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

            ShareLink(item: DeepLinkService.generateShareURL(for: news)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                UIPasteboard.general.string = news.neutralTitle
                copyHeadlineTrigger.toggle()
            } label: {
                Label("Copy headline", systemImage: "doc.on.doc")
            }
        }
        .sensoryFeedback(.success, trigger: saveFeedbackTrigger)
        .sensoryFeedback(.success, trigger: copyHeadlineTrigger)
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
        let currentlySaved = SavedNewsService.shared.isNewsSaved(newsId: news.id, context: context)
        do {
            if currentlySaved {
                let unsaveRegionRaw = vm.isShowingSavedNews ? vm.savedRegionRaw(for: news.id) : nil
                try SavedNewsService.shared.unsaveNews(newsId: news.id, context: context, regionRaw: unsaveRegionRaw)
                await MainActor.run {
                    vm.removeFromSavedNews(news.id)
                    savedNewsState.setSaved(false, for: news.id, regionRaw: unsaveRegionRaw)
                    saveFeedbackTrigger &+= 1
                }
            } else {
                try SavedNewsService.shared.saveNews(news, context: context)
                await MainActor.run {
                    RatingManager.shared.incrementSavedNewsCount()
                    RatingManager.shared.requestRatingAfterPositiveInteraction()
                    savedNewsState.setSaved(true, for: news.id)
                    saveFeedbackTrigger &+= 1
                }
            }
        } catch {
            print("❌ Error saving/unsaving article: \(error)")
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
}
