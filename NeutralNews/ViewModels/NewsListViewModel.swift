//
//  NewsListViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation

@Observable
final class NewsListViewModel {
    static let shared = NewsListViewModel()
    
    // MARK: - Init
    private init() {
        findNearestDayWithNewsOnLaunch()
        loadNewsForSelectedDay()
        
        // Pre-load cache in background
        Task {
            await newsDataManager.preloadCache()
        }
    }
    
    // MARK: - Dependencies
    private let newsDataManager = NewsDataManager.shared
    private let filterViewModel = NewsFilterViewModel.shared
    
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
    
    // MARK: - Computed Properties
    var lastSevenDays: [DayInfo] {
        newsDataManager.lastSevenDays
    }
    
    var newsToShow: [NeutralNews] {
        if isShowingAllDays {
            return filterViewModel.applyFilters(to: paginatedNews, daySelected: daySelected)
        } else {
            let dayNews = newsDataManager.getNewsArrayForDay(daySelected)
            return filterViewModel.applyFilters(to: dayNews, daySelected: daySelected)
        }
    }
    
    private var allAvailableNews: [NeutralNews] {
        Array(Set(newsDataManager.neutralNews))
            .sorted { $0.date > $1.date }
    }
    
    var searchText: String {
        get { filterViewModel.searchText }
        set { 
            filterViewModel.searchText = newValue
            if isShowingAllDays {
                resetPagination()
                loadInitialPage()
            }
        }
    }
    
    var categoryFilter: Set<Category> {
        get { filterViewModel.categoryFilter }
        set { 
            filterViewModel.categoryFilter = newValue
            if isShowingAllDays {
                resetPagination()
                loadInitialPage()
            }
        }
    }
    
    var orderBy: OrderBy {
        get { filterViewModel.orderBy }
        set { 
            filterViewModel.orderBy = newValue
            if isShowingAllDays {
                resetPagination()
                loadInitialPage()
            }
        }
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
    private var paginatedNews: [NeutralNews] = []
    private var currentPage = 0
    private let pageSize = 20
    var isLoadingMore = false
    var hasMorePages = true
    
    // MARK: - Public Methods
    
    func changeDay(to dayInfo: DayInfo) {
        isShowingAllDays = false
        daySelected = dayInfo
        searchScope = .daySelected
    }
    
    func changeToAllDays() {
        isShowingAllDays = true
        searchScope = .lastSevenDays
        resetPagination()
        loadInitialPage()
    }
    
    func getRelatedNews(from neutralNews: NeutralNews) -> [News] {
        newsDataManager.getRelatedNews(from: neutralNews)
    }
    
    func getCategoriesOfTheDay() -> [Category] {
        let newsToFilter = isShowingAllDays 
            ? newsToShow
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
    
    private func resetPagination() {
        paginatedNews.removeAll()
        currentPage = 0
        hasMorePages = true
        isLoadingMore = false
    }
    
    private func loadInitialPage() {
        guard hasMorePages else { return }
        
        let startIndex = 0
        let endIndex = min(pageSize, allAvailableNews.count)
        
        guard startIndex < allAvailableNews.count else {
            hasMorePages = false
            return
        }
        
        let newItems = Array(allAvailableNews[startIndex..<endIndex])
        paginatedNews = newItems
        currentPage = 1
        
        hasMorePages = endIndex < allAvailableNews.count
    }
    
    func loadNextPage() {
        guard hasMorePages && !isLoadingMore else { return }
        
        isLoadingMore = true
        
        // Simulate network delay for smooth UX
        Task {
            await MainActor.run {
                let startIndex = currentPage * pageSize
                let endIndex = min(startIndex + pageSize, allAvailableNews.count)
                
                guard startIndex < allAvailableNews.count else {
                    hasMorePages = false
                    isLoadingMore = false
                    return
                }
                
                let newItems = Array(allAvailableNews[startIndex..<endIndex])
                paginatedNews.append(contentsOf: newItems)
                currentPage += 1
                
                hasMorePages = endIndex < allAvailableNews.count
                isLoadingMore = false
            }
        }
    }
    
    func shouldLoadMore(currentItem: NeutralNews) -> Bool {
        guard isShowingAllDays,
              let lastItem = paginatedNews.last,
              lastItem.id == currentItem.id else { return false }
        
        return hasMorePages && !isLoadingMore
    }
    
    private func findNews(group: Int, date: Date) -> NeutralNews? {
        let calendar = Calendar.current
        return newsDataManager.neutralNews.first { news in
            news.group == group && calendar.isDate(news.date, inSameDayAs: date)
        }
    }
    
    func handleDeepLink(_ deepLinkData: DeepLinkService.DeepLinkData) {
        // Si hay datos, procesar inmediatamente
        if !newsDataManager.neutralNews.isEmpty {
            processDeepLink(deepLinkData)
        } else {
            // Si no hay datos, guardar para procesar cuando lleguen
            pendingDeepLink = deepLinkData
        }
    }
    
    private func processDeepLink(_ deepLinkData: DeepLinkService.DeepLinkData) {
#if DEBUG
        print("🔄 Processing deep link in ViewModel - group: \(deepLinkData.group)")
#endif
        
        // Cambiar al día correcto
        let dayInfo = DayInfo(date: deepLinkData.date)
        changeDay(to: dayInfo)
        
        // Esperar a que la vista se actualice después del cambio de día
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            // Buscar y marcar la noticia objetivo
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
}
