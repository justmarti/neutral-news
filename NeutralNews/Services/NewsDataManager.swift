//
//  NewsDataManager.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation

extension Notification.Name {
    static let newsDidUpdate = Notification.Name("NewsDidUpdate")
}

@Observable
final class NewsDataManager {
    static let shared = NewsDataManager()

    // MARK: - Dependencies
    private let cacheService = CacheService.shared

    // MARK: - Data Collections
    private(set) var allNews = [News]() {
        didSet {
            NotificationCenter.default.post(name: .newsDidUpdate, object: nil)
        }
    }
    private(set) var neutralNews = [NeutralNews]() {
        didSet {
            NotificationCenter.default.post(name: .newsDidUpdate, object: nil)
        }
    }

    // MARK: - Optimized News by Day Storage
    private(set) var newsByDay: [Date: Set<NeutralNews>] = [:]
    
    // MARK: - Optimized Cache Management
    private var loadedDays: Set<Date> = Set<Date>()
    
    // Helper functions to avoid bridging issues with Date in Set and Dictionary operations
    private func isDateLoaded(_ date: Date) -> Bool {
        return (loadedDays as Set<Date>).contains(date)
    }
    
    private func markDateAsLoaded(_ date: Date) {
        loadedDays.insert(date)
    }
    
    private func removeDateFromLoaded(_ date: Date) {
        loadedDays.remove(date)
    }
    
    private func removeNewsForDate(_ date: Date) {
        newsByDay.removeValue(forKey: date)
    }
    
    private func getNewsSetForDate(_ date: Date) -> Set<NeutralNews> {
        return newsByDay[date] ?? Set<NeutralNews>()
    }
    
    private func setNewsForDate(_ news: Set<NeutralNews>, date: Date) {
        newsByDay[date] = news
    }
    
    private func ensureNewsSetExists(for date: Date) {
        if newsByDay[date] == nil {
            newsByDay[date] = Set<NeutralNews>()
        }
    }
    
    private func addNewsToDate(_ news: Set<NeutralNews>, date: Date) {
        ensureNewsSetExists(for: date)
        newsByDay[date]?.formUnion(news)
    }
    
    // MARK: - Background Loading
    private var backgroundLoadingTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    var lastSevenDays: [DayInfo] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            return DayInfo(date: date)
        }
    }
    
    deinit {
        backgroundLoadingTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func loadNews(for day: DayInfo, forceRefresh: Bool = false) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        
        // Skip if already loaded unless forced refresh
        guard !isDateLoaded(startOfDay) || forceRefresh else { return }
        
        // Step 1: Try cache first (unless force refresh)
        if !forceRefresh && cacheService.isCacheValid(for: day) {
#if DEBUG
            print("📱 Cache HIT for \(day.dayName)")
#endif
            
            let cachedNeutralNews = cacheService.getCachedNeutralNews(for: day)
            let cachedNews = cacheService.getCachedNews(for: day)
            
            await MainActor.run {
                self.addNewNewsForDay(
                    neutralNews: cachedNeutralNews,
                    regularNews: cachedNews,
                    for: startOfDay
                )
                self.markDateAsLoaded(startOfDay)
            }
            return
        }
        
        // Step 2: Cache miss or force refresh - fetch from Firebase
#if DEBUG
        print("🔥 Cache MISS for \(day.dayName) - fetching from Firebase")
#endif
        
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
                self.markDateAsLoaded(startOfDay)
                
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
#if DEBUG
                print("🔄 Using stale cache as fallback for \(day.dayName)")
#endif
                await MainActor.run {
                    self.addNewNewsForDay(
                        neutralNews: cachedNeutralNews,
                        regularNews: cachedNews,
                        for: startOfDay
                    )
                    self.markDateAsLoaded(startOfDay)
                }
            }
        }
    }
    
    func refreshNews(for day: DayInfo) async {
        await loadNews(for: day, forceRefresh: true)
    }
    
    func getNewsForDay(_ dayInfo: DayInfo) -> Set<NeutralNews> {
        cleanOldMemoryDataIfNeeded()
        let startOfDay = Calendar.current.startOfDay(for: dayInfo.date)
        return getNewsSetForDate(startOfDay)
    }
    
    func getNewsArrayForDay(_ day: DayInfo) -> [NeutralNews] {
        let newsSet = getNewsForDay(day)
        return Array(newsSet).sorted { $0.date > $1.date }
    }
    
    func getRelatedNews(from neutralNews: NeutralNews) -> [News] {
        return allNews.filter { neutralNews.sourceIds.contains($0.id) }
    }
    
    func isDayLoaded(_ day: DayInfo) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        return isDateLoaded(startOfDay)
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
#if DEBUG
            print("🔥 Pre-loading today's cache")
#endif
            await loadNews(for: today)
        }
    }

    func startBackgroundLoadingIfNeeded() {
        // Only start if not already running
        guard backgroundLoadingTask == nil else { return }
        startProgressiveLoading()
    }

    // MARK: - Private Methods
    
    private func addNewNewsForDay(
        neutralNews fetchedNeutralNews: [NeutralNews],
        regularNews fetchedNews: [News],
        for date: Date
    ) {
        // Add only truly new neutral news that don't exist yet
        let newNeutralNews = fetchedNeutralNews.filter { fetchedNews in
            !neutralNews.contains { existingNews in existingNews.id == fetchedNews.id }
        }
        
        if !newNeutralNews.isEmpty {
            self.neutralNews.append(contentsOf: newNeutralNews)
            self.addNewsToDay(newNeutralNews, for: date)
        }
        
        // Add only truly new regular news that don't exist yet
        let newNews = fetchedNews.filter { fetchedNews in
            !allNews.contains { existingNews in existingNews.id == fetchedNews.id }
        }
        
        if !newNews.isEmpty {
            self.allNews.append(contentsOf: newNews)
        }
    }
    
    private func mergeNewsForDay(
        neutralNews fetchedNeutralNews: [NeutralNews],
        regularNews fetchedNews: [News],
        for date: Date
    ) {
        // Step 1: Update existing neutral news with fresh data
        let fetchedNeutralNewsDict = Dictionary(uniqueKeysWithValues: fetchedNeutralNews.map { ($0.id, $0) })
        
        for i in neutralNews.indices {
            if let freshNews = fetchedNeutralNewsDict[neutralNews[i].id] {
                neutralNews[i] = freshNews
            }
        }
        
        // Step 2: Add only genuinely new items that don't exist yet
        let newNeutralNews = fetchedNeutralNews.filter { fetchedNews in
            !neutralNews.contains { existingNews in existingNews.id == fetchedNews.id }
        }
        
        if !newNeutralNews.isEmpty {
            neutralNews.append(contentsOf: newNeutralNews)
        }
        
        // Step 3: Update the day collection with fresh data
        ensureNewsSetExists(for: date)
        setNewsForDate(Set(fetchedNeutralNews), date: date)
        
        // Step 4: Handle regular news similarly
        let fetchedNewsDict = Dictionary(uniqueKeysWithValues: fetchedNews.map { ($0.id, $0) })
        
        // Update existing items
        for i in allNews.indices {
            if let freshNews = fetchedNewsDict[allNews[i].id] {
                allNews[i] = freshNews
            }
        }
        
        // Add only genuinely new items that don't exist yet
        let newNews = fetchedNews.filter { fetchedNews in
            !allNews.contains { existingNews in existingNews.id == fetchedNews.id }
        }
        
        if !newNews.isEmpty {
            allNews.append(contentsOf: newNews)
        }
    }
    
    private func addNewsToDay(_ news: [NeutralNews], for date: Date) {
        addNewsToDate(Set(news), date: date)
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

        // Smart loading: only load days accessible to user
        let maxDaysToLoad = PremiumManager.shared.isPremium ? 6 : 1
        let priorityOrder = Array(1...maxDaysToLoad)
        
        for dayOffset in priorityOrder {
            if Task.isCancelled { return }
            
            guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let startOfDay = calendar.startOfDay(for: dayDate)
            
            // Skip if already loaded in memory
            if isDateLoaded(startOfDay) { continue }
            
            let dayInfo = DayInfo(date: dayDate)
            
            // Check cache validity first - if valid, load immediately without delay
            if cacheService.isCacheValid(for: dayInfo) {
#if DEBUG
                print("🚀 Fast cache load for background day: \(dayInfo.dayName)")
#endif
                await loadNews(for: dayInfo)
                continue
            }
            
            // Only add delay for Firebase fetches
            let delay = dayOffset <= 2 ? 300_000_000 : 800_000_000 // 0.3s for recent, 0.8s for older
            try? await Task.sleep(nanoseconds: UInt64(delay))
            
            if Task.isCancelled { return }
            
#if DEBUG
            print("🐌 Firebase fetch for background day: \(dayInfo.dayName)")
#endif
            await loadNews(for: dayInfo)
        }
    }
    
    private func cleanOldMemoryDataIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        // Remove old data from memory (older than 7 days)
        let oldDates = newsByDay.keys.filter { $0 < sevenDaysAgo }
        guard !oldDates.isEmpty else { return }
        
        oldDates.forEach { date in
            removeNewsForDate(date)
            removeDateFromLoaded(date)
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
    }
}
