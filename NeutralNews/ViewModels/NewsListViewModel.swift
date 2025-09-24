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
                print("🔄 isShowingSavedNews changed to: \(isShowingSavedNews)")
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
        let newsToFilter = isShowingAllDays 
            ? allAvailableNews
            : newsDataManager.getNewsArrayForDay(daySelected)
        let categoriesSet = Set(newsToFilter.compactMap { Category(rawValue: $0.category) })
        return Category.allCases.filter { categoriesSet.contains($0) }
    }
    
    func refreshNews() async {
        isLoadingNeutralNews = true
        await newsDataManager.refreshNews(for: daySelected)
        isLoadingNeutralNews = false
    }
    
    func forceLoadNews() async {
        isLoadingNeutralNews = true
        await newsDataManager.loadNews(for: daySelected, forceRefresh: true)
        isLoadingNeutralNews = false
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
        // Always fetch today's news first before deciding
        Task {
            await newsDataManager.loadNews(for: .today)
            
            let todayNews = newsDataManager.getNewsArrayForDay(.today)
            if !todayNews.isEmpty {
                return // Today has news after fetch, keep it selected
            }
            
            // Today is empty after fetch, find another day with news
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
    
    private func findNews(group: Int, date: Date) -> NeutralNews? {
        let calendar = Calendar.current
        return newsDataManager.neutralNews.first { news in
            news.group == group && calendar.isDate(news.date, inSameDayAs: date)
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
        print("🔄 Processing deep link in ViewModel - group: \(deepLinkData.group)")
#endif
        
        let dayInfo = DayInfo(date: deepLinkData.date)
        changeDay(to: dayInfo)
        
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            if let news = self.findNews(group: deepLinkData.group, date: deepLinkData.date) {
#if DEBUG
                print("✅ News found: \(news.neutralTitle)")
#endif
                self.deepLinkTargetNews = news
            } else {
#if DEBUG
                print("❌ News not found - group: \(deepLinkData.group), total news: \(self.newsDataManager.neutralNews.count)")
#endif
            }
        }
        
        pendingDeepLink = nil
    }
    
    func checkPendingDeepLink() {
        guard let pendingDeepLink = pendingDeepLink,
              !newsDataManager.neutralNews.isEmpty else { return }
        processDeepLink(pendingDeepLink)
    }

    // MARK: - Saved News Methods

    func toggleSavedNewsMode() {
        isShowingSavedNews.toggle()

        // Clear filters when entering saved news mode
        if isShowingSavedNews {
            filterViewModel.clearFilters()
        }
    }

    func loadSavedNews() async {
        guard let context = coreDataContext else {
            print("❌ No Core Data context available")
            return
        }

        print("🔄 Loading saved news from Core Data")

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
            print("📰 Found \(savedNewsItems.count) saved news items")

            // Convert saved news back to NeutralNews objects
            let neutralNewsList = savedNewsItems.compactMap { savedNews -> NeutralNews? in
                guard savedNews.newsType == SavedNewsType.neutralNews.rawValue else {
                    print("⚠️ Skipping non-neutral news: \(savedNews.newsType ?? "unknown")")
                    return nil
                }

                // Create NeutralNews from saved data
                return savedNews.toNeutralNews()
            }

            print("✅ Successfully parsed \(neutralNewsList.count) neutral news items")

            await MainActor.run {
                savedNews = neutralNewsList.sorted { $0.date > $1.date }
                print("🎯 savedNews updated with \(savedNews.count) items")
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
