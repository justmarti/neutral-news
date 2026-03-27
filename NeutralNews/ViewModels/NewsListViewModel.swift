//
//  NewsListViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftData
import CoreData
import Observation

@MainActor
@Observable
final class NewsListViewModel {
    actor ObservationStreamState {
        private var isTerminated = false

        func terminate() {
            isTerminated = true
        }

        func canContinue() -> Bool {
            !isTerminated
        }
    }

    struct DeepLinkNavigationTarget: Identifiable, Hashable {
        let news: NeutralNews
        let relatedNews: [News]
        let region: ContentRegion

        var id: String { news.id }
    }

    static let shared = NewsListViewModel()
    
    // MARK: - Init
    private init() {
        findNearestDayWithNewsOnLaunch()
        
        filterViewModel.onFiltersChanged = { [weak self] in
            self?.handleFilterChanges()
        }

        recomputeVisibleNews()
        
        Task {
            // Wait for premium status to be ready before starting background loading
            await PremiumManager.shared.checkSubscriptionStatus()

            // Now start background loading with correct premium status
            newsDataManager.startBackgroundLoadingIfNeeded()
        }
    }
    
    // MARK: - Dependencies
    let newsDataManager = NewsDataManager.shared
    let filterViewModel = NewsFilterViewModel.shared
    let savedNewsService = SavedNewsService.shared

    // Model context for SwiftData (cache) - will be injected
    var modelContext: ModelContext?

    // Core Data context for saved news - will be injected
    var coreDataContext: NSManagedObjectContext?
    
    // MARK: - UI State
    var daySelected: DayInfo = .today {
        didSet {
            if daySelected != oldValue {
                recomputeVisibleNews()
                scheduleSelectedDayLoadIfNeeded()
            }
        }
    }
    
    var isLoadingNeutralNews = false
    var isLoadingForSearch = false
    var hasCompletedInitialLaunchLoad = false

    // MARK: - Saved News State
    var isShowingSavedNews = false {
        didSet {
            if isShowingSavedNews != oldValue {
#if DEBUG
                print("🔄 isShowingSavedNews changed to: \(isShowingSavedNews)")
#endif
                if isShowingSavedNews {
                    selectedDayLoadTask?.cancel()
                    selectedDayLoadTask = nil
                    dayFeedPrefetchTask?.cancel()
                    lastDayPrefetchHash = 0
                    isLoadingNeutralNews = false
                    Task {
                        await loadSavedNews()
                    }
                } else {
                    savedNewsPrefetchTask?.cancel()
                    recomputeVisibleNews()
                }
            }
        }
    }
    var savedNews: [NeutralNews] = [] {
        didSet {
            if isShowingSavedNews {
                refreshSavedNewsPaginationIfNeeded(forceReconfigure: true)
            } else {
                recomputeVisibleNews()
            }
        }
    }
    var isLoadingSavedNews = false
    var savedRelatedNewsByNeutralId: [String: [News]] = [:]
    var savedRegionByNewsId: [String: String] = [:]
    
    // MARK: - Computed Properties
    var lastSevenDays: [DayInfo] {
        newsDataManager.lastSevenDays
    }
    
    var newsToShow: [NeutralNews] {
        visibleNews
    }

    private func computeNewsToShow() -> [NeutralNews] {
        if isShowingSavedNews {
            return savedPaginationManager.paginatedItems
        } else if isShowingAllDays || searchScope == .lastSevenDays {
            return paginationManager.paginatedItems
        } else {
            let dayNews = newsDataManager.getNewsArrayForDay(daySelected)
            return filterViewModel.applyFilters(to: dayNews, daySelected: daySelected)
        }
    }
    
    var isLoadingMore: Bool {
        if isShowingSavedNews {
            return savedPaginationManager.isLoading
        }
        return paginationManager.isLoading
    }

    var isShowingLimitedSearchResults: Bool {
        searchScope == .lastSevenDays && !PremiumManager.shared.isPremium
    }
    
    private var allAvailableNews: [NeutralNews] {
        let currentNews = newsDataManager.neutralNews
        let currentHash = hashNewsData(currentNews)
        
        // Cache optimization: avoid recalculations
        if currentHash != lastNewsDataHash {
            cachedAllNews = Array(Set(currentNews)).sorted { $0.date > $1.date }
            lastNewsDataHash = currentHash
        }
        
        return cachedAllNews
    }
    
    var searchText: String {
        get { filterViewModel.searchText }
        set { filterViewModel.searchText = newValue }
    }
    
    var categoryFilter: Set<Category> {
        get { filterViewModel.categoryFilter }
        set { filterViewModel.categoryFilter = newValue }
    }
    
    var orderBy: OrderBy {
        get { filterViewModel.orderBy }
        set { filterViewModel.orderBy = newValue }
    }
    
    var isAnyFilterEnabled: Bool {
        filterViewModel.isAnyFilterEnabled
    }
    
    var searchScope: SearchScope {
        get { filterViewModel.searchScope }
        set { filterViewModel.searchScope = newValue }
    }
    
    var isShowingAllDays = false

    var savedNewsSubtitle: LocalizedStringResource {
        let filteredCount = savedPaginationManager.totalItemCount
        let totalCount = savedNews.count

        if isAnyFilterEnabled && filteredCount != totalCount {
            return "\(filteredCount) out of \(totalCount) news articles"
        } else {
            return "\(totalCount) news articles"
        }
    }
    
    // MARK: - Pagination

    private let paginationManager = PaginationManager<NeutralNews>()
    private let savedPaginationManager = PaginationManager<NeutralNews>()
    private var cachedAllNews: [NeutralNews] = []
    private var lastNewsDataHash: Int = 0
    private var isObservingNewsDataChanges = false
    private var allDaysLoadingTask: Task<Void, Never>?
    var deepLinkLookupTask: Task<Void, Never>?
    var savedNewsPrefetchTask: Task<Void, Never>?
    private var dayFeedPrefetchTask: Task<Void, Never>?
    private var selectedDayLoadTask: Task<Void, Never>?
    private var lastDayPrefetchHash: Int = 0
    private var lastVisibleNewsHash: Int?
    private(set) var visibleNews: [NeutralNews] = []

    // MARK: - Public Methods

    /// Changes the selected day and switches to single-day view mode.
    ///
    /// - Parameter dayInfo: The day to display news for
    /// - Note: Automatically resets search scope to `.daySelected` and disables "all days" mode.
    func changeDay(to dayInfo: DayInfo) {
        allDaysLoadingTask?.cancel()
        allDaysLoadingTask = nil
        isShowingAllDays = false
        searchScope = .daySelected

        if daySelected != dayInfo {
            daySelected = dayInfo
        } else {
            recomputeVisibleNews()
            scheduleSelectedDayLoadIfNeeded()
        }
    }

    /// Switches to "all days" view mode showing news from the last 7 days.
    ///
    /// - Note: Automatically updates search scope to `.lastSevenDays` and configures pagination.
    /// - Important: Premium users can access this feature without restrictions. Free users have limited access.
    func changeToAllDays() {
        selectedDayLoadTask?.cancel()
        selectedDayLoadTask = nil
        dayFeedPrefetchTask?.cancel()
        lastDayPrefetchHash = 0
        isLoadingNeutralNews = false
        isShowingAllDays = true
        searchScope = .lastSevenDays
        let filteredNews = filterViewModel.applyFilters(to: allAvailableNews, daySelected: daySelected)
        paginationManager.configure(with: filteredNews)
        recomputeVisibleNews()

        startLoadingMissingLastSevenDaysIfNeeded()
    }
    
    /// Retrieves all related news articles from different media sources for a neutral news item.
    ///
    /// - Parameter neutralNews: The neutral news item to find related articles for
    /// - Returns: Array of `News` items from various media outlets referenced in the neutral news
    func getRelatedNews(from neutralNews: NeutralNews) -> [News] {
        let liveRelatedNews = newsDataManager.getRelatedNews(from: neutralNews)
        if !liveRelatedNews.isEmpty {
            return liveRelatedNews
        }

        if isShowingSavedNews {
            return savedRelatedNewsByNeutralId[neutralNews.id] ?? []
        }

        return []
    }
    
    /// Retrieves all news categories available for the current view context.
    ///
    /// Returns categories present in the currently displayed news set (saved news, all days, or selected day).
    /// Categories are returned in the order defined by `Category.allCases`.
    ///
    /// - Returns: Array of `Category` values that have at least one news item in the current context
    func getCategoriesOfTheDay() -> [Category] {
        let newsToFilter: [NeutralNews]

        if isShowingSavedNews {
            newsToFilter = savedNews
        } else if isShowingAllDays {
            newsToFilter = allAvailableNews
        } else {
            newsToFilter = newsDataManager.getNewsArrayForDay(daySelected)
        }

        let categoriesSet = Set(newsToFilter.compactMap { Category.fromBackendValue($0.category) })
        return Category.allCases.filter { categoriesSet.contains($0) }
    }
    
    /// Forces a refresh of news data for the currently selected day.
    ///
    /// Bypasses cache and fetches fresh data from Firebase. Updates UI loading state automatically.
    /// Use this for pull-to-refresh functionality or when fresh data is explicitly required.
    ///
    /// - Note: This is an async operation that updates `isLoadingNeutralNews` state
    func refreshNews() async {
        await MainActor.run {
            isLoadingNeutralNews = true
        }

        await newsDataManager.refreshNews(for: daySelected)

        await MainActor.run {
            isLoadingNeutralNews = false
        }
    }
    
    /// Forces a complete reload of news data for the currently selected day.
    ///
    /// Similar to `refreshNews()` but uses the direct `loadNews(forceRefresh:)` method.
    /// Updates UI loading state automatically.
    ///
    /// - Note: This is an async operation that updates `isLoadingNeutralNews` state
    func forceLoadNews() async {
        await MainActor.run {
            isLoadingNeutralNews = true
        }

        await newsDataManager.loadNews(for: daySelected, forceRefresh: true)

        await MainActor.run {
            isLoadingNeutralNews = false
        }
    }

    /// Preloads today's news on app resume without forcing refresh or UI loading state.
    ///
    /// This avoids competing with user-driven navigation when coming back from background.
    func preloadTodayOnResume() async {
        guard !isShowingSavedNews else { return }
        await newsDataManager.loadNews(for: .today)
    }

    /// Handles content region changes by resetting data and reloading current context.
    ///
    /// In all-days/search scope, reloads all last-7-days data to keep pagination consistent.
    /// In single-day scope, reloads only the selected day.
    func reloadAfterRegionChange() async {
        allDaysLoadingTask?.cancel()
        allDaysLoadingTask = nil

        await MainActor.run {
            isLoadingNeutralNews = true
            paginationManager.reset()
        }

        await newsDataManager.resetForRegionChange()

        if isShowingAllDays || searchScope == .lastSevenDays {
            await loadMissingLastSevenDays(showLoading: true)
            await MainActor.run {
                let filteredNews = filterViewModel.applyFilters(to: allAvailableNews, daySelected: daySelected)
                paginationManager.configure(with: filteredNews)
                recomputeVisibleNews()
                isLoadingNeutralNews = false
            }
        } else {
            await newsDataManager.loadNews(for: daySelected, forceRefresh: true)
            await MainActor.run {
                recomputeVisibleNews()
                isLoadingNeutralNews = false
            }
        }
    }
    
    /// Toggles the filter for a specific news category.
    ///
    /// If the category is already filtered, it will be removed. If not, it will be added.
    ///
    /// - Parameter category: The category to toggle in the filter
    func filterByCategory(_ category: Category) {
        filterViewModel.filterByCategory(category)
    }
    
    /// Clears all active filters (search text, categories, etc.) but preserves ordering.
    func clearFilters() {
        filterViewModel.clearFilters()
    }
    
    /// Resets all filters and ordering to their default values.
    func resetToDefaults() {
        filterViewModel.resetToDefaults()
    }
    
    // MARK: - Private Methods
    
    private func scheduleSelectedDayLoadIfNeeded() {
        let selectedDay = daySelected

        // Keep only the latest day-change request active.
        selectedDayLoadTask?.cancel()

        // If we already have this day in memory, avoid any extra work.
        if newsDataManager.isDayLoaded(selectedDay) {
            isLoadingNeutralNews = false
            selectedDayLoadTask = nil
            return
        }

        selectedDayLoadTask = Task { [weak self] in
            guard let self else { return }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.isLoadingNeutralNews = true
            }

            await self.newsDataManager.loadNews(for: selectedDay)

            await MainActor.run {
                guard self.daySelected == selectedDay else { return }
                self.isLoadingNeutralNews = false
                self.recomputeVisibleNews()
                self.selectedDayLoadTask = nil
            }
        }
    }
    
    private func findNearestDayWithNewsOnLaunch() {
        startObservingNewsDataChangesIfNeeded()

        Task {
            await MainActor.run {
                isLoadingNeutralNews = true
                hasCompletedInitialLaunchLoad = false
            }

            await newsDataManager.loadNews(for: .today)

            let todayNews = newsDataManager.getNewsArrayForDay(.today)
            if !todayNews.isEmpty {
                // Today has news, check for pending deep link
                checkPendingDeepLink()
                // Don't set isLoadingNeutralNews = false here if there's a deep link
                // processDeepLink will handle it
                if pendingDeepLink == nil {
                    await MainActor.run {
                        isLoadingNeutralNews = false
                        hasCompletedInitialLaunchLoad = true
                    }
                }
                return
            }

            // Today is empty - handle differently based on deep link
            if pendingDeepLink != nil {
                // Load all days in parallel to find the deep link target quickly
                let daysToLoad = Array(lastSevenDays.dropFirst())
                await withTaskGroup(of: Void.self) { group in
                    for day in daysToLoad { // Skip today (already loaded)
                        group.addTask { [day] in
                            await NewsDataManager.shared.loadNews(for: day)
                        }
                    }
                }
                checkPendingDeepLink()
                // Don't set isLoadingNeutralNews = false here
                // processDeepLink will handle it when news is found
                return
            }

            // No deep link - normal behavior: find day with news and select it
            for day in lastSevenDays.dropFirst() { // Skip today (index 0)
                await newsDataManager.loadNews(for: day)
                let dayNews = newsDataManager.getNewsArrayForDay(day)
                if !dayNews.isEmpty {
                    await MainActor.run {
                        daySelected = day
                        isLoadingNeutralNews = false
                        hasCompletedInitialLaunchLoad = true
                    }
                    return
                }
            }

            await MainActor.run {
                isLoadingNeutralNews = false
                hasCompletedInitialLaunchLoad = true
            }
        }
    }
    
    var pendingDeepLink: DeepLinkService.DeepLinkData?
    var deepLinkTargetNews: DeepLinkNavigationTarget?
    
    // MARK: - Pagination Methods
    
    /// Loads the next page of items for the active paginated list (all days or saved news).
    ///
    /// - Note: Triggered from row `onAppear` in all-days and saved-news modes.
    func loadNextPage() {
        if isShowingSavedNews {
            savedPaginationManager.loadNextPage()
            recomputeVisibleNews()
            return
        }

        paginationManager.loadNextPage()
        recomputeVisibleNews()
    }
    
    /// Determines if more news items should be loaded when scrolling reaches a specific item.
    ///
    /// Used for infinite scroll functionality in the all days view.
    ///
    /// - Parameter currentItem: The news item currently being displayed
    /// - Returns: `true` if more items should be loaded, `false` otherwise
    func shouldLoadMore(currentItem: NeutralNews) -> Bool {
        if isShowingSavedNews {
            return savedPaginationManager.shouldLoadMore(for: currentItem)
        }

        guard isShowingAllDays || searchScope == .lastSevenDays else { return false }
        return paginationManager.shouldLoadMore(for: currentItem)
    }
    
    private func refreshPaginationIfNeeded() {
        guard isShowingAllDays || searchScope == .lastSevenDays else { return }
        let filteredNews = filterViewModel.applyFilters(to: allAvailableNews, daySelected: daySelected)
        paginationManager.reconfigure(with: filteredNews)
        recomputeVisibleNews()
    }

    private func refreshSavedNewsPaginationIfNeeded(forceReconfigure: Bool) {
        guard isShowingSavedNews else { return }

        let filteredSavedNews = filterViewModel.applyFilters(to: savedNews)
        if forceReconfigure {
            savedPaginationManager.reconfigure(with: filteredSavedNews)
        } else {
            savedPaginationManager.configure(with: filteredSavedNews)
        }
        recomputeVisibleNews()
    }

    private func startObservingNewsDataChangesIfNeeded() {
        guard !isObservingNewsDataChanges else { return }
        isObservingNewsDataChanges = true
        observeNewsDataChanges()
    }

    private func observeNewsDataChanges() {
        withObservationTracking {
            _ = newsDataManager.neutralNews
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleNewsDatasetUpdate()
                self.observeNewsDataChanges()
            }
        }
    }

    private func handleNewsDatasetUpdate() {
        if isShowingAllDays || searchScope == .lastSevenDays {
            refreshPaginationIfNeeded()
        } else {
            recomputeVisibleNews()
        }
    }
    
    private func handleFilterChanges() {
        if isShowingSavedNews {
            refreshSavedNewsPaginationIfNeeded(forceReconfigure: true)
            return
        }

        if searchScope == .lastSevenDays && !isShowingAllDays {
            refreshPaginationIfNeeded()
            startLoadingMissingLastSevenDaysIfNeeded()
        } else {
            if isShowingAllDays || searchScope == .lastSevenDays {
                refreshPaginationIfNeeded()
            } else {
                recomputeVisibleNews()
            }
        }
    }

    private func startLoadingMissingLastSevenDaysIfNeeded() {
        guard allDaysLoadingTask == nil else { return }

        allDaysLoadingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.allDaysLoadingTask = nil
                }
            }

            await self.loadMissingLastSevenDays(showLoading: true)
        }
    }

    private func loadMissingLastSevenDays(showLoading: Bool) async {
        let daysToLoad = lastSevenDays.filter { !newsDataManager.isDayLoaded($0) }

        guard !daysToLoad.isEmpty else {
            if showLoading {
                isLoadingForSearch = false
            }
            return
        }

        if showLoading {
            isLoadingForSearch = true
        }

        defer {
            if showLoading {
                isLoadingForSearch = false
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for day in daysToLoad {
                group.addTask { [day] in
                    await NewsDataManager.shared.loadNews(for: day)
                }
            }

            await group.waitForAll()
        }

        guard !Task.isCancelled else { return }
        refreshPaginationIfNeeded()
    }
    
    private func findNews(newsId: String) -> NeutralNews? {
        return newsDataManager.neutralNews.first { news in
            news.id == newsId
        }
    }

    private func hashNewsData(_ news: [NeutralNews]) -> Int {
        var hasher = Hasher()
        hasher.combine(news.count)

        for item in news {
            hasher.combine(item.id)
            hasher.combine(item.updatedAt.timeIntervalSince1970)
            hasher.combine(item.date.timeIntervalSince1970)
        }

        return hasher.finalize()
    }

    /// Recomputes `visibleNews` from the current view state.
    ///
    /// - Important: Call this method after mutating mode, selected day, filters, sorting,
    ///   pagination state, or the underlying datasets.
    ///
    /// Keep this as the single entry point for updating `visibleNews` so state changes stay
    /// consistent. If a new state dependency is added and this method is not called after that
    /// dependency changes, the UI can display stale data.
    ///
    /// Complexity is O(n), where `n` is the number of items in the active source list.
    private func recomputeVisibleNews() {
        let newVisibleNews = computeNewsToShow()
        let newVisibleNewsHash = hashNewsData(newVisibleNews)
        guard lastVisibleNewsHash != newVisibleNewsHash else { return }

        lastVisibleNewsHash = newVisibleNewsHash
        visibleNews = newVisibleNews
        scheduleDayFeedPrefetchIfNeeded()
    }

    private func scheduleDayFeedPrefetchIfNeeded() {
        guard !isShowingSavedNews else { return }
        guard !isShowingAllDays else { return }
        guard searchScope == .daySelected else { return }

        let prefetchURLs = visibleNews
            .prefix(12)
            .compactMap { URL(string: $0.imageUrl) }

        if prefetchURLs.isEmpty {
            dayFeedPrefetchTask?.cancel()
            dayFeedPrefetchTask = nil
            lastDayPrefetchHash = 0
            return
        }

        var hasher = Hasher()
        hasher.combine(prefetchURLs.count)
        for url in prefetchURLs {
            hasher.combine(url.absoluteString)
        }
        let newHash = hasher.finalize()
        guard newHash != lastDayPrefetchHash else { return }
        lastDayPrefetchHash = newHash

        dayFeedPrefetchTask?.cancel()
        dayFeedPrefetchTask = Task(priority: .utility) {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await CachedAsyncImageHelper.prefetchImages(from: prefetchURLs)
        }
    }

}
