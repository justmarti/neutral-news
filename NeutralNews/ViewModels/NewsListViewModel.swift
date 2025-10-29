//
//  NewsListViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftData
import CoreData

@Observable
final class NewsListViewModel {
    static let shared = NewsListViewModel()
    
    // MARK: - Init
    private init() {
        findNearestDayWithNewsOnLaunch()
        loadNewsForSelectedDay()
        
        filterViewModel.onFiltersChanged = { [weak self] in
            self?.handleFilterChanges()
        }
        
        Task {
            await newsDataManager.preloadCache()

            // Wait for premium status to be ready before starting background loading
            await PremiumManager.shared.checkSubscriptionStatus()

            // Now start background loading with correct premium status
            newsDataManager.startBackgroundLoadingIfNeeded()
        }
    }
    
    // MARK: - Dependencies
    private let newsDataManager = NewsDataManager.shared
    private let filterViewModel = NewsFilterViewModel.shared
    private let savedNewsService = SavedNewsService.shared

    // Model context for SwiftData (cache) - will be injected
    var modelContext: ModelContext?

    // Core Data context for saved news - will be injected
    var coreDataContext: NSManagedObjectContext?
    
    // MARK: - UI State
    var daySelected: DayInfo = .today {
        didSet {
            if daySelected != oldValue {
                Task {
                    await refreshNews()
                }
            }
        }
    }
    
    var isLoadingNeutralNews = false
    var isLoadingForSearch = false

    // MARK: - Saved News State
    var isShowingSavedNews = false {
        didSet {
            if isShowingSavedNews != oldValue {
#if DEBUG
                print("🔄 isShowingSavedNews changed to: \(isShowingSavedNews)")
#endif
                if isShowingSavedNews {
                    Task {
                        await loadSavedNews()
                    }
                }
            }
        }
    }
    var savedNews: [NeutralNews] = []
    var isLoadingSavedNews = false
    
    // MARK: - Computed Properties
    var lastSevenDays: [DayInfo] {
        newsDataManager.lastSevenDays
    }
    
    var newsToShow: [NeutralNews] {
        if isShowingSavedNews {
            return filterViewModel.applyFilters(to: savedNews)
        } else if isShowingAllDays || searchScope == .lastSevenDays {
            return paginationManager.paginatedItems
        } else {
            let dayNews = newsDataManager.getNewsArrayForDay(daySelected)
            return filterViewModel.applyFilters(to: dayNews, daySelected: daySelected)
        }
    }
    
    var isLoadingMore: Bool {
        paginationManager.isLoading
    }

    var isShowingLimitedSearchResults: Bool {
        searchScope == .lastSevenDays && !PremiumManager.shared.isPremium
    }
    
    private var allAvailableNews: [NeutralNews] {
        let currentNews = newsDataManager.neutralNews
        let currentHash = currentNews.count
        
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

    var savedNewsSubtitle: String {
        let filteredCount = newsToShow.count
        let totalCount = savedNews.count

        if isAnyFilterEnabled && filteredCount != totalCount {
            return "\(filteredCount) de \(totalCount) noticias"
        } else {
            return "\(totalCount) noticias"
        }
    }
    
    // MARK: - Pagination
    
    private let paginationManager = PaginationManager<NeutralNews>()
    private var cachedAllNews: [NeutralNews] = []
    private var lastNewsDataHash: Int = 0
    
    // MARK: - Public Methods

    /// Changes the selected day and switches to single-day view mode.
    ///
    /// - Parameter dayInfo: The day to display news for
    /// - Note: Automatically resets search scope to `.daySelected` and disables "all days" mode.
    func changeDay(to dayInfo: DayInfo) {
        isShowingAllDays = false
        daySelected = dayInfo
        searchScope = .daySelected
    }

    /// Switches to "all days" view mode showing news from the last 7 days.
    ///
    /// - Note: Automatically updates search scope to `.lastSevenDays` and configures pagination.
    /// - Important: Premium users can access this feature without restrictions. Free users have limited access.
    func changeToAllDays() {
        isShowingAllDays = true
        searchScope = .lastSevenDays
        let filteredNews = filterViewModel.applyFilters(to: allAvailableNews, daySelected: daySelected)
        paginationManager.configure(with: filteredNews)
    }
    
    /// Retrieves all related news articles from different media sources for a neutral news item.
    ///
    /// - Parameter neutralNews: The neutral news item to find related articles for
    /// - Returns: Array of `News` items from various media outlets referenced in the neutral news
    func getRelatedNews(from neutralNews: NeutralNews) -> [News] {
        newsDataManager.getRelatedNews(from: neutralNews)
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

        let categoriesSet = Set(newsToFilter.compactMap { Category(rawValue: $0.category) })
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
    
    private func loadNewsForSelectedDay() {
        // Don't load if already loaded
        guard !newsDataManager.isDayLoaded(daySelected) else { return }
        
        Task {
            await MainActor.run {
                isLoadingNeutralNews = true
            }
            
            await newsDataManager.loadNews(for: daySelected)
            
            await MainActor.run {
                isLoadingNeutralNews = false
            }
        }
    }
    
    private func findNearestDayWithNewsOnLaunch() {
        Task {
            // Show loading if we have a pending deep link
            if pendingDeepLink != nil {
                await MainActor.run {
                    isLoadingNeutralNews = true
                }
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
                    }
                }
                return
            }

            // Today is empty - handle differently based on deep link
            if pendingDeepLink != nil {
                // Load all days in parallel to find the deep link target quickly
                await withTaskGroup(of: Void.self) { group in
                    for day in lastSevenDays.dropFirst() { // Skip today (already loaded)
                        group.addTask {
                            await self.newsDataManager.loadNews(for: day)
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
                    }
                    return
                }
            }
        }
    }
    
    var pendingDeepLink: DeepLinkService.DeepLinkData?
    var deepLinkTargetNews: NeutralNews?
    
    // MARK: - Pagination Methods
    
    /// Loads the next page of news items when using pagination (all days view).
    ///
    /// - Note: Only applicable when `isShowingAllDays` is `true` or `searchScope == .lastSevenDays`
    func loadNextPage() {
        paginationManager.loadNextPage()
    }
    
    /// Determines if more news items should be loaded when scrolling reaches a specific item.
    ///
    /// Used for infinite scroll functionality in the all days view.
    ///
    /// - Parameter currentItem: The news item currently being displayed
    /// - Returns: `true` if more items should be loaded, `false` otherwise
    func shouldLoadMore(currentItem: NeutralNews) -> Bool {
        guard isShowingAllDays || searchScope == .lastSevenDays else { return false }
        return paginationManager.shouldLoadMore(for: currentItem)
    }
    
    private func refreshPaginationIfNeeded() {
        guard isShowingAllDays || searchScope == .lastSevenDays else { return }
        let filteredNews = filterViewModel.applyFilters(to: allAvailableNews, daySelected: daySelected)
        paginationManager.reconfigure(with: filteredNews)
    }
    
    private func handleFilterChanges() {
        if searchScope == .lastSevenDays && !isShowingAllDays {
            // Load all days for both free and premium users
            // Premium users might have background loading still in progress
            // loadNews() will skip already-loaded days automatically
            Task {
                await loadAllDaysForSearch()
                // Configure pagination AFTER loading completes
                await MainActor.run {
                    let filteredNews = filterViewModel.applyFilters(to: allAvailableNews, daySelected: daySelected)
                    paginationManager.configure(with: filteredNews)
                }
            }
        } else {
            refreshPaginationIfNeeded()
        }
    }

    private func loadAllDaysForSearch() async {
        await MainActor.run {
            isLoadingForSearch = true
        }

        // Load all 7 days in parallel
        await withTaskGroup(of: Void.self) { group in
            for day in lastSevenDays {
                group.addTask {
                    await self.newsDataManager.loadNews(for: day)
                }
            }
        }

        await MainActor.run {
            isLoadingForSearch = false
        }
    }
    
    private func findNews(newsId: String) -> NeutralNews? {
        return newsDataManager.neutralNews.first { news in
            news.id == newsId
        }
    }

    // MARK: - Reactive News Updates Stream

    /// Creates an AsyncStream that emits whenever news data is updated
    private var newsUpdatesStream: AsyncStream<[NeutralNews]> {
        AsyncStream { continuation in
            // Emit current value immediately
            continuation.yield(newsDataManager.neutralNews)

            // Observe future updates
            let observer = NotificationCenter.default.addObserver(
                forName: .newsDidUpdate,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                continuation.yield(self.newsDataManager.neutralNews)
            }

            // Cleanup when stream terminates
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    /// Handles incoming deep link requests to navigate to a specific news article.
    ///
    /// If news data is already loaded, processes the deep link immediately. Otherwise, stores it
    /// as pending and waits for news to load. Uses reactive AsyncStream for efficient waiting.
    ///
    /// - Parameter deepLinkData: The deep link data containing the target news ID
    /// - Note: Sets `isLoadingNeutralNews` to `true` during processing
    /// - Important: Automatically clears loading state once article is found or timeout occurs (10s)
    func handleDeepLink(_ deepLinkData: DeepLinkService.DeepLinkData) {
        isLoadingNeutralNews = true

        if !newsDataManager.neutralNews.isEmpty {
            processDeepLink(deepLinkData)
        } else {
            pendingDeepLink = deepLinkData
        }
    }

    private func processDeepLink(_ deepLinkData: DeepLinkService.DeepLinkData) {
#if DEBUG
        print("🔄 Processing deep link in ViewModel - newsId: \(deepLinkData.newsId)")
#endif

        // Try to find the news immediately
        if let news = findNews(newsId: deepLinkData.newsId) {
#if DEBUG
            print("✅ News found immediately: \(news.neutralTitle)")
#endif
            deepLinkTargetNews = news
            pendingDeepLink = nil
            isLoadingNeutralNews = false
            return
        }

        // If not found, wait reactively for news to load
#if DEBUG
        print("⏳ News not loaded yet, listening for updates...")
#endif

        Task {
            // Use reactive stream instead of polling with timeout
            await withTaskGroup(of: Bool.self) { group in
                // Task 1: Search for news reactively
                group.addTask {
                    for await newsArray in self.newsUpdatesStream {
                        if let news = newsArray.first(where: { $0.id == deepLinkData.newsId }) {
#if DEBUG
                            print("✅ News found reactively: \(news.neutralTitle)")
#endif
                            await MainActor.run {
                                self.deepLinkTargetNews = news
                                self.pendingDeepLink = nil
                                self.isLoadingNeutralNews = false
                            }
                            return true
                        }
                    }
                    return false
                }

                // Task 2: Timeout after 10 seconds
                group.addTask {
                    try? await Task.sleep(for: .seconds(10))
                    return false
                }

                // Wait for first task to complete (race condition)
                if let found = await group.next(), found {
                    // News found! Cancel the timeout
                    group.cancelAll()
                } else {
                    // Timeout or not found
#if DEBUG
                    print("❌ News not found within timeout - newsId: \(deepLinkData.newsId)")
#endif
                    await MainActor.run {
                        self.pendingDeepLink = nil
                        self.isLoadingNeutralNews = false
                    }
                    group.cancelAll()
                }
            }
        }
    }
    
    func checkPendingDeepLink() {
        guard let pendingDeepLink = pendingDeepLink,
              !newsDataManager.neutralNews.isEmpty else { return }
        processDeepLink(pendingDeepLink)
    }

    // MARK: - Saved News Methods

    /// Toggles between saved news view and regular news view.
    ///
    /// Automatically clears all active filters when switching modes to prevent confusion.
    ///
    /// - Note: When entering saved news mode, automatically triggers `loadSavedNews()`
    /// - Important: Premium feature - requires `PremiumManager.canSaveNews` permission
    func toggleSavedNewsMode() {
        isShowingSavedNews.toggle()
        filterViewModel.clearFilters()
    }

    /// Loads all saved news from Core Data persistent storage.
    ///
    /// Fetches saved news items from Core Data, converts them back to `NeutralNews` objects,
    /// and updates the `savedNews` array sorted by date (newest first).
    ///
    /// - Important: Requires `coreDataContext` to be set. Will fail silently if not available.
    /// - Note: This is an async operation that updates `isLoadingSavedNews` state
    func loadSavedNews() async {
        guard let context = coreDataContext else {
            print("❌ No Core Data context available")
            return
        }

#if DEBUG
        print("🔄 Loading saved news from Core Data")
#endif

        await MainActor.run {
            isLoadingSavedNews = true
        }

        defer {
            Task { @MainActor in
                isLoadingSavedNews = false
            }
        }

        do {
            let savedNewsItems = try savedNewsService.getSavedNews(context: context)
#if DEBUG
            print("📰 Found \(savedNewsItems.count) saved news items")
#endif

            // Convert saved news back to NeutralNews objects
            let neutralNewsList = savedNewsItems.compactMap { savedNews -> NeutralNews? in
                guard savedNews.newsType == SavedNewsType.neutralNews.rawValue else {
#if DEBUG
                    print("⚠️ Skipping non-neutral news: \(savedNews.newsType ?? "unknown")")
#endif
                    return nil
                }

                // Create NeutralNews from saved data
                return savedNews.toNeutralNews()
            }

#if DEBUG
            print("✅ Successfully parsed \(neutralNewsList.count) neutral news items")
#endif

            await MainActor.run {
                savedNews = neutralNewsList.sorted { $0.date > $1.date }
#if DEBUG
                print("🎯 savedNews updated with \(savedNews.count) items")
#endif
            }
        } catch {
            print("❌ Error loading saved news: \(error)")
            await MainActor.run {
                savedNews = []
            }
        }
    }


    /// Removes a news item from the saved news array (UI state only).
    ///
    /// This only removes the item from the in-memory array. To permanently delete from Core Data,
    /// use `SavedNewsService.deleteSavedNews()`.
    ///
    /// - Parameter newsId: The ID of the news item to remove from the array
    func removeFromSavedNews(_ newsId: String) {
        savedNews.removeAll { $0.id == newsId }
    }

}
