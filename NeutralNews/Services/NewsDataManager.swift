//
//  NewsDataManager.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation

@Observable
final class NewsDataManager {
    static let shared = NewsDataManager()
    
    // MARK: - Dependencies
    private let cacheService = CacheService.shared
    
    // MARK: - Data Collections
    private(set) var allNews = [News]()
    private(set) var neutralNews = [NeutralNews]()
    private(set) var groupsOfNews = [[News]]()
    
    // MARK: - Optimized News by Day Storage
    private(set) var newsByDay: [Date: Set<NeutralNews>] = [:]
    
    // MARK: - Optimized Cache Management
    private var loadedDays = Set<Date>()
    private var loadedNewsIds = Set<String>()
    private var loadedNeutralNewsIds = Set<String>()
    
    // MARK: - Background Loading
    private var backgroundLoadingTask: Task<Void, Never>?
    private var lastExecutionDate: Date?
    
    // MARK: - Computed Properties
    var lastSevenDays: [DayInfo] {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        let monthFormatter = DateFormatter()
        
        dayFormatter.locale = Locale(identifier: "es_ES")
        dayFormatter.dateFormat = "EEEE"
        
        monthFormatter.locale = Locale(identifier: "es_ES")
        monthFormatter.dateFormat = "MMMM"
        
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            
            let dayNumber = calendar.component(.day, from: date)
            let monthName = monthFormatter.string(from: date)
            
            let dayName: String
            switch offset {
            case 0: dayName = "Hoy"
            case 1: dayName = "Ayer"
            default: dayName = dayFormatter.string(from: date).capitalized
            }
            
            return DayInfo(
                dayName: dayName,
                dayNumber: dayNumber,
                monthName: monthName,
                date: date
            )
        }
    }
    
    private init() {
        startProgressiveLoading()
        setupDayChangeTimer()
    }
    
    deinit {
        backgroundLoadingTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func loadNews(for day: DayInfo, forceRefresh: Bool = false) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        
        // Skip if already loaded unless forced refresh
        guard !loadedDays.contains(startOfDay) || forceRefresh else { return }
        
        // Step 1: Try cache first (unless force refresh)
        if !forceRefresh && cacheService.isCacheValid(for: day) {
            print("📱 Cache HIT for \(day.dayName)")
            
            let cachedNeutralNews = cacheService.getCachedNeutralNews(for: day)
            let cachedNews = cacheService.getCachedNews(for: day)
            
            await MainActor.run {
                self.addNewNewsForDay(
                    neutralNews: cachedNeutralNews,
                    regularNews: cachedNews,
                    for: startOfDay
                )
                self.loadedDays.insert(startOfDay)
            }
            return
        }
        
        // Step 2: Cache miss or force refresh - fetch from Firebase
        print("🔥 Cache MISS for \(day.dayName) - fetching from Firebase")
        
        do {
            async let neutralNewsTask = FirestoreService.shared.fetchNeutralNews(for: day)
            async let newsTask = FirestoreService.shared.fetchNews(for: day)
            
            let (fetchedNeutralNews, fetchedNews) = try await (neutralNewsTask, newsTask)
            
            await MainActor.run {
                if forceRefresh {
                    // Smart incremental refresh: merge instead of replace
                    self.mergeNewsForDay(
                        neutralNews: fetchedNeutralNews,
                        regularNews: fetchedNews,
                        for: startOfDay
                    )
                } else {
                    // Normal loading: add only new items
                    self.addNewNewsForDay(
                        neutralNews: fetchedNeutralNews,
                        regularNews: fetchedNews,
                        for: startOfDay
                    )
                }
                
                // Mark day as loaded
                self.loadedDays.insert(startOfDay)
                
                // Cache the fresh data after processing
                self.cacheService.cacheNeutralNews(fetchedNeutralNews, for: day)
                self.cacheService.cacheNews(fetchedNews, for: day)
            }
        } catch {
            print("❌ Error loading news for \(day.dayName): \(error.localizedDescription)")
            
            // Fallback: try to load from cache even if potentially stale
            let cachedNeutralNews = cacheService.getCachedNeutralNews(for: day)
            let cachedNews = cacheService.getCachedNews(for: day)
            
            if !cachedNeutralNews.isEmpty || !cachedNews.isEmpty {
                print("🔄 Using stale cache as fallback for \(day.dayName)")
                await MainActor.run {
                    self.addNewNewsForDay(
                        neutralNews: cachedNeutralNews,
                        regularNews: cachedNews,
                        for: startOfDay
                    )
                    self.loadedDays.insert(startOfDay)
                }
            }
        }
    }
    
    func refreshNews(for day: DayInfo) async {
        await loadNews(for: day, forceRefresh: true)
    }
    
    func getNewsForDay(_ dayInfo: DayInfo) -> Set<NeutralNews> {
        let startOfDay = Calendar.current.startOfDay(for: dayInfo.date)
        return newsByDay[startOfDay] ?? Set<NeutralNews>()
    }
    
    func getNewsArrayForDay(_ day: DayInfo) -> [NeutralNews] {
        let newsSet = getNewsForDay(day)
        return Array(newsSet).sorted { $0.date > $1.date }
    }
    
    func getRelatedNews(from neutralNews: NeutralNews) -> [News] {
        groupsOfNews.first(where: { $0.first?.group == neutralNews.group }) ?? []
    }
    
    func isDayLoaded(_ day: DayInfo) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        return loadedDays.contains(startOfDay)
    }
    
    func getCacheStats() -> (memory: Int, persistent: (neutralNews: Int, news: Int)) {
        let memoryCount = loadedDays.count
        let persistentStats = cacheService.getCacheStats()
        return (memory: memoryCount, persistent: persistentStats)
    }
    
    func preloadCache() async {
        // Pre-load today in case it's not cached yet
        let today = DayInfo.today
        if !cacheService.isCacheValid(for: today) {
            print("🔥 Pre-loading today's cache")
            await loadNews(for: today)
        }
    }
    
    // MARK: - Private Methods
    
    private func addNewNewsForDay(
        neutralNews fetchedNeutralNews: [NeutralNews],
        regularNews fetchedNews: [News],
        for date: Date
    ) {
        // Add only truly new neutral news
        let newNeutralNews = fetchedNeutralNews.filter { news in
            !self.loadedNeutralNewsIds.contains(news.id)
        }
        
        if !newNeutralNews.isEmpty {
            self.neutralNews.append(contentsOf: newNeutralNews)
            self.loadedNeutralNewsIds.formUnion(newNeutralNews.map(\.id))
            self.addNewsToDay(newNeutralNews, for: date)
        }
        
        // Add only truly new regular news
        let newNews = fetchedNews.filter { news in
            !self.loadedNewsIds.contains(news.id)
        }
        
        if !newNews.isEmpty {
            self.allNews.append(contentsOf: newNews)
            self.loadedNewsIds.formUnion(newNews.map(\.id))
            self.filterGroupedNews()
        }
    }
    
    private func mergeNewsForDay(
        neutralNews fetchedNeutralNews: [NeutralNews],
        regularNews fetchedNews: [News],
        for date: Date
    ) {
        // Step 1: Update existing neutral news with fresh data
        let fetchedNeutralNewsDict = Dictionary(uniqueKeysWithValues: fetchedNeutralNews.map { ($0.id, $0) })
        
        // Update existing items in neutralNews array
        for i in neutralNews.indices {
            if let freshNews = fetchedNeutralNewsDict[neutralNews[i].id] {
                let oldDate = Calendar.current.startOfDay(for: neutralNews[i].date)
                if oldDate == date {
                    neutralNews[i] = freshNews
                }
            }
        }
        
        // Step 2: Add genuinely new items
        let newNeutralNews = fetchedNeutralNews.filter { news in
            !self.loadedNeutralNewsIds.contains(news.id)
        }
        
        if !newNeutralNews.isEmpty {
            self.neutralNews.append(contentsOf: newNeutralNews)
            self.loadedNeutralNewsIds.formUnion(newNeutralNews.map(\.id))
        }
        
        // Step 3: Update the day collection with ALL current news for this day
        if newsByDay[date] == nil {
            newsByDay[date] = Set<NeutralNews>()
        }
        
        // Replace the day's collection with fresh data
        newsByDay[date] = Set(fetchedNeutralNews)
        
        // Step 4: Handle regular news similarly
        let fetchedNewsDict = Dictionary(uniqueKeysWithValues: fetchedNews.map { ($0.id, $0) })
        
        // Update existing items
        for i in allNews.indices {
            if let freshNews = fetchedNewsDict[allNews[i].id] {
                let oldDate = Calendar.current.startOfDay(for: allNews[i].pubDate)
                if oldDate == date {
                    allNews[i] = freshNews
                }
            }
        }
        
        // Add new items
        let newNews = fetchedNews.filter { news in
            !self.loadedNewsIds.contains(news.id)
        }
        
        if !newNews.isEmpty {
            self.allNews.append(contentsOf: newNews)
            self.loadedNewsIds.formUnion(newNews.map(\.id))
        }
        
        // Step 5: Update grouped news
        self.filterGroupedNews()
    }
    
    private func addNewsToDay(_ news: [NeutralNews], for date: Date) {
        if newsByDay[date] == nil {
            newsByDay[date] = Set<NeutralNews>()
        }
        newsByDay[date]?.formUnion(news)
    }
    
    private func startProgressiveLoading() {
        backgroundLoadingTask?.cancel()
        
        backgroundLoadingTask = Task(priority: .utility) {
            await loadRemainingDays()
        }
    }
    
    @MainActor
    private func loadRemainingDays() async {
        let calendar = Calendar.current
        let today = Date()
        
        // Smart loading: prioritize recent days and check cache first
        let priorityOrder = [1, 2, 3, 4, 5, 6] // días hacia atrás
        
        for dayOffset in priorityOrder {
            if Task.isCancelled { return }
            
            guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let startOfDay = calendar.startOfDay(for: dayDate)
            
            // Skip if already loaded in memory
            if loadedDays.contains(startOfDay) { continue }
            
            let dayInfo = createDayInfo(for: dayDate)
            
            // Check cache validity first - if valid, load immediately without delay
            if cacheService.isCacheValid(for: dayInfo) {
                print("🚀 Fast cache load for background day: \(dayInfo.dayName)")
                await loadNews(for: dayInfo)
                continue
            }
            
            // Only add delay for Firebase fetches
            let delay = dayOffset <= 2 ? 300_000_000 : 800_000_000 // 0.3s for recent, 0.8s for older
            try? await Task.sleep(nanoseconds: UInt64(delay))
            
            if Task.isCancelled { return }
            
            print("🐌 Firebase fetch for background day: \(dayInfo.dayName)")
            await loadNews(for: dayInfo)
        }
    }
    
    private func createDayInfo(for date: Date) -> DayInfo {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        let monthFormatter = DateFormatter()
        
        dayFormatter.locale = Locale(identifier: "es_ES")
        dayFormatter.dateFormat = "EEEE"
        
        monthFormatter.locale = Locale(identifier: "es_ES")
        monthFormatter.dateFormat = "MMMM"
        
        let dayNumber = calendar.component(.day, from: date)
        let monthName = monthFormatter.string(from: date)
        let dayName = dayFormatter.string(from: date).capitalized
        
        return DayInfo(
            dayName: dayName,
            dayNumber: dayNumber,
            monthName: monthName,
            date: date
        )
    }
    
    private func filterGroupedNews() {
        let groupedNews = Dictionary(grouping: allNews, by: { $0.group })
        let filteredGroups = groupedNews.filter { $0.value.count > 1 && $0.key != -1 }
        
        let sortedGroups = filteredGroups.sorted { group1, group2 in
            guard let latestNews1 = group1.value.first, let latestNews2 = group2.value.first else {
                return false
            }
            return latestNews1.pubDate > latestNews2.pubDate
        }
        
        groupsOfNews = sortedGroups.map { $0.value }
    }
    
    private func setupDayChangeTimer() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let tomorrow = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) else { return }
        
        let timeInterval = tomorrow.timeIntervalSince(Date())
        
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.handleDayChange()
            self?.setupDayChangeTimer()
        }
    }
    
    private func handleDayChange() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        // Remove old data from memory (older than 7 days)
        let oldDates = newsByDay.keys.filter { $0 < sevenDaysAgo }
        oldDates.forEach { date in
            newsByDay[date] = nil
            loadedDays.remove(date)
        }
        
        // Also clean old news from arrays
        neutralNews.removeAll { news in
            let newsDate = calendar.startOfDay(for: news.date)
            return newsDate < sevenDaysAgo
        }
        
        allNews.removeAll { news in
            let newsDate = calendar.startOfDay(for: news.pubDate)
            return newsDate < sevenDaysAgo
        }
        
        // Clean cache and refresh group filtering
        cacheService.cleanExpiredCache()
        filterGroupedNews()
        
        lastExecutionDate = Date()
        startProgressiveLoading()
    }
}
