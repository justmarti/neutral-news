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
    
    func changeDay(to dayInfo: DayInfo) {
        isShowingAllDays = false
        daySelected = dayInfo
        searchScope = .daySelected
    }

    func changeToAllDays() {
        isShowingAllDays = true
        searchScope = .lastSevenDays
        let filteredNews = filterViewModel.applyFilters(to: allAvailableNews, daySelected: daySelected)
        paginationManager.configure(with: filteredNews)
    }
    
    func getRelatedNews(from neutralNews: NeutralNews) -> [News] {
        newsDataManager.getRelatedNews(from: neutralNews)
    }
    
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
    
    func refreshNews() async {
        await MainActor.run {
            isLoadingNeutralNews = true
        }

        await newsDataManager.refreshNews(for: daySelected)

        await MainActor.run {
            isLoadingNeutralNews = false
        }
    }
    
    func forceLoadNews() async {
        await MainActor.run {
            isLoadingNeutralNews = true
        }

        await newsDataManager.loadNews(for: daySelected, forceRefresh: true)

        await MainActor.run {
            isLoadingNeutralNews = false
        }
    }
    
    func filterByCategory(_ category: Category) {
        filterViewModel.filterByCategory(category)
    }
    
    func clearFilters() {
        filterViewModel.clearFilters()
    }
    
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
            await newsDataManager.loadNews(for: .today)

            let todayNews = newsDataManager.getNewsArrayForDay(.today)
            if !todayNews.isEmpty {
                // Today has news, check for pending deep link
                checkPendingDeepLink()
                return
            }

            // Today is empty - handle differently based on deep link
            if pendingDeepLink != nil {
                // Load previous days to find the deep link target
                for day in lastSevenDays.dropFirst() { // Skip today (index 0)
                    await newsDataManager.loadNews(for: day)
                    checkPendingDeepLink()
                    if pendingDeepLink == nil { break } // Deep link was processed
                }
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
    
    private var pendingDeepLink: DeepLinkService.DeepLinkData?
    var deepLinkTargetNews: NeutralNews?
    
    // MARK: - Pagination Methods
    
    func loadNextPage() {
        paginationManager.loadNextPage()
    }
    
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
            let filteredNews = filterViewModel.applyFilters(to: allAvailableNews, daySelected: daySelected)
            paginationManager.configure(with: filteredNews)
        } else {
            refreshPaginationIfNeeded()
        }
    }
    
    private func findNews(newsId: String) -> NeutralNews? {
        return newsDataManager.neutralNews.first { news in
            news.id == newsId
        }
    }
    
    func handleDeepLink(_ deepLinkData: DeepLinkService.DeepLinkData) {
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
            return
        }

        // If not found, wait for news to load
#if DEBUG
        print("⏳ News not loaded yet, waiting for data...")
#endif

        Task {
            // Wait for news data to be available with timeout
            let maxAttempts = 10
            let delayPerAttempt: UInt64 = 500_000_000 // 0.5s

            for attempt in 1...maxAttempts {
                if let news = self.findNews(newsId: deepLinkData.newsId) {
#if DEBUG
                    print("✅ News found after \(attempt) attempts: \(news.neutralTitle)")
#endif
                    await MainActor.run {
                        self.deepLinkTargetNews = news
                        self.pendingDeepLink = nil
                    }
                    return
                }

                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: delayPerAttempt)
                }
            }

#if DEBUG
            print("❌ News not found after \(maxAttempts) attempts - newsId: \(deepLinkData.newsId)")
#endif
            await MainActor.run {
                self.pendingDeepLink = nil
            }
        }
    }
    
    func checkPendingDeepLink() {
        guard let pendingDeepLink = pendingDeepLink,
              !newsDataManager.neutralNews.isEmpty else { return }
        processDeepLink(pendingDeepLink)
    }

    // MARK: - Saved News Methods

    func toggleSavedNewsMode() {
        isShowingSavedNews.toggle()
        filterViewModel.clearFilters()
    }

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


    func removeFromSavedNews(_ newsId: String) {
        savedNews.removeAll { $0.id == newsId }
    }

}
