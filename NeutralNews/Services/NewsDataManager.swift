//
//  NewsDataManager.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import WidgetKit

private final class RegularNewsLoadCoordinator {
    private var tasksByDay: [Date: Task<Void, Never>] = [:]
    private var sessionID = UUID()

    @MainActor
    func currentSessionID() -> UUID {
        sessionID
    }

    @MainActor
    func isCurrentSession(_ id: UUID) -> Bool {
        sessionID == id
    }

    @MainActor
    func storeTask(_ task: Task<Void, Never>, for date: Date) {
        cancelTask(for: date)
        tasksByDay[date] = task
    }

    @MainActor
    func removeTask(for date: Date) {
        tasksByDay.removeValue(forKey: date)
    }

    @MainActor
    func cancelTask(for date: Date) {
        tasksByDay[date]?.cancel()
        tasksByDay.removeValue(forKey: date)
    }

    @MainActor
    func invalidateSession() {
        cancelAll()
        sessionID = UUID()
    }

    @MainActor
    func cancelAll() {
        tasksByDay.values.forEach { $0.cancel() }
        tasksByDay.removeAll()
    }
}

private actor DayLoadGate {
    struct Handle: Sendable {
        let token: UUID
        let task: Task<Void, Never>
        let isNew: Bool
    }

    private var loadedDays: Set<Date> = []
    private var tasksByDay: [Date: (token: UUID, task: Task<Void, Never>)] = [:]

    func handleForLoad(
        for date: Date,
        forceRefresh: Bool,
        createTask: @Sendable () -> Task<Void, Never>
    ) -> Handle? {
        if !forceRefresh {
            if loadedDays.contains(date) {
                return nil
            }

            if let existing = tasksByDay[date] {
                return Handle(token: existing.token, task: existing.task, isNew: false)
            }
        }

        if forceRefresh {
            loadedDays.remove(date)
            tasksByDay[date]?.task.cancel()
        }

        let token = UUID()
        let task = createTask()
        tasksByDay[date] = (token, task)
        return Handle(token: token, task: task, isNew: true)
    }

    func clearIfCurrent(for date: Date, token: UUID) {
        guard tasksByDay[date]?.token == token else { return }
        tasksByDay.removeValue(forKey: date)
    }

    func markLoaded(_ date: Date) {
        loadedDays.insert(date)
    }

    func removeLoadedDates(_ dates: [Date]) {
        for date in dates {
            loadedDays.remove(date)
        }
    }

    func reset() {
        tasksByDay.values.forEach { $0.task.cancel() }
        tasksByDay.removeAll()
        loadedDays.removeAll()
    }
}

@Observable
final class NewsDataManager {
    static let shared = NewsDataManager()

    // MARK: - Dependencies
    private let cacheService = CacheService.shared
    private let widgetSnapshotStore = WidgetSnapshotStore()

    // MARK: - Data Collections
    private(set) var allNews = [News]() {
        didSet {
            // Keep O(1) lookup for related-news resolution in Home cards.
            newsById = Dictionary(uniqueKeysWithValues: allNews.map { ($0.id, $0) })
        }
    }
    private(set) var neutralNews = [NeutralNews]()
    private var newsById: [String: News] = [:]

    // MARK: - Optimized News by Day Storage
    private(set) var newsByDay: [Date: Set<NeutralNews>] = [:]
    
    // Helper functions to avoid bridging issues with Date in dictionary operations
    private func isDateLoaded(_ date: Date) -> Bool {
        newsByDay[date] != nil
    }
    
    private func markDateAsLoaded(_ date: Date) {
        ensureNewsSetExists(for: date)
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
    private let dayLoadGate = DayLoadGate()
    private let regularNewsLoadCoordinator = RegularNewsLoadCoordinator()
    
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
        Task { @MainActor [regularNewsLoadCoordinator] in
            regularNewsLoadCoordinator.cancelAll()
        }
        Task { [dayLoadGate] in
            await dayLoadGate.reset()
        }
    }
    
    // MARK: - Public Methods

    /// Loads news for a specific day with intelligent caching strategy.
    ///
    /// This method implements a three-tier loading strategy:
    /// 1. Check SwiftData cache (fastest)
    /// 2. Fetch from Firebase if cache miss or expired
    /// 3. Fall back to stale cache on network error
    ///
    /// - Parameters:
    ///   - day: The day to load news for
    ///   - forceRefresh: If `true`, bypasses cache and forces a fresh Firebase fetch. Default is `false`.
    ///
    /// - Note: This method is safe to call multiple times for the same day - it automatically skips if already loaded.
    /// - Important: Runs on background thread and updates observed state when complete.
    func loadNews(for day: DayInfo, forceRefresh: Bool = false) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)

        guard !isDateLoaded(startOfDay) || forceRefresh else { return }

        let dayDate = day.date
        let dayName = day.dayName

        let handle = await dayLoadGate.handleForLoad(
            for: startOfDay,
            forceRefresh: forceRefresh,
            createTask: { [weak self] in
                Task { [weak self] in
                    guard let self else { return }
                    await self.performLoadNews(
                        for: day,
                        startOfDay: startOfDay,
                        dayDate: dayDate,
                        dayName: dayName,
                        forceRefresh: forceRefresh
                    )
                }
            }
        )

        guard let handle else {
            return
        }

        await handle.task.value

        if handle.isNew {
            await dayLoadGate.clearIfCurrent(for: startOfDay, token: handle.token)
        }
    }

    /// Refreshes a day only when the local cache has expired.
    ///
    /// This keeps foreground activation cheap when the in-memory data is still fresh, while allowing
    /// already-loaded days to fetch new Firebase data after the cache TTL expires.
    func refreshNewsIfNeeded(for day: DayInfo) async {
        let shouldRefresh = !cacheService.isNeutralNewsCacheValid(for: day)
            || !cacheService.isNewsCacheValid(for: day)

        await loadNews(for: day, forceRefresh: shouldRefresh)
    }

    private func performLoadNews(
        for day: DayInfo,
        startOfDay: Date,
        dayDate: Date,
        dayName: String,
        forceRefresh: Bool
    ) async {
        let sessionID = await MainActor.run {
            self.regularNewsLoadCoordinator.currentSessionID()
        }

        // Step 1: Try cached neutral news first (unless force refresh).
        if !forceRefresh && cacheService.isNeutralNewsCacheValid(for: day) {
#if DEBUG
            print("📱 Cache HIT for \(day.dayName)")
#endif

            let hasRegularCache = cacheService.isNewsCacheValid(for: day)
            let cachedNeutralNews = cacheService.getCachedNeutralNews(for: day)
            let cachedNews = hasRegularCache ? cacheService.getCachedNews(for: day) : []

            await MainActor.run {
                self.addNewNewsForDay(
                    neutralNews: cachedNeutralNews,
                    regularNews: cachedNews,
                    for: startOfDay
                )
                self.markDateAsLoaded(startOfDay)
            }
            await dayLoadGate.markLoaded(startOfDay)

            if !hasRegularCache {
                await startRegularNewsLoad(
                    for: dayDate,
                    startOfDay: startOfDay,
                    dayName: dayName,
                    sessionID: sessionID
                )
            }

            return
        }
        
        // Step 2: Cache miss or force refresh - fetch from Firebase
#if DEBUG
        print("🔥 Cache MISS for \(dayName) - fetching from Firebase")
#endif

        if forceRefresh {
            await MainActor.run {
                self.regularNewsLoadCoordinator.cancelTask(for: startOfDay)
            }

            do {
                async let neutralNewsTask = FirestoreService.shared.fetchNeutralNews(for: day)
                async let newsTask = FirestoreService.shared.fetchNews(for: day)

                let (fetchedNeutralNews, fetchedNews) = try await (neutralNewsTask, newsTask)

                let shouldCache = await MainActor.run {
                    guard self.regularNewsLoadCoordinator.isCurrentSession(sessionID) else { return false }

                    // Smart incremental refresh: merge instead of replace
                    self.mergeNewsForDay(
                        neutralNews: fetchedNeutralNews,
                        regularNews: fetchedNews,
                        for: startOfDay
                    )

                    // Mark day as loaded
                    self.markDateAsLoaded(startOfDay)
                    return true
                }

                if shouldCache {
                    await dayLoadGate.markLoaded(startOfDay)
                    let dayInfo = DayInfo(date: dayDate)
                    Task(priority: .utility) { [cacheService] in
                        cacheService.cacheNeutralNews(fetchedNeutralNews, for: dayInfo)
                        cacheService.cacheNews(fetchedNews, for: dayInfo)
                    }
                }
            } catch {
                print("❌ Error loading news for \(dayName): \(error.localizedDescription)")

                // Fallback: try to load from local cache even if it is past the refresh TTL.
                let cachedNeutralNews = cacheService.getStaleCachedNeutralNews(for: day)
                let cachedNews = cacheService.getStaleCachedNews(for: day)

                if !cachedNeutralNews.isEmpty || !cachedNews.isEmpty {
#if DEBUG
                    print("🔄 Using stale cache as fallback for \(dayName)")
#endif
                    await MainActor.run {
                        guard self.regularNewsLoadCoordinator.isCurrentSession(sessionID) else { return }

                        self.addNewNewsForDay(
                            neutralNews: cachedNeutralNews,
                            regularNews: cachedNews,
                            for: startOfDay
                        )
                        self.markDateAsLoaded(startOfDay)
                    }
                    await dayLoadGate.markLoaded(startOfDay)
                }
            }
            return
        }

        // For initial/day loading, prioritize neutral news so Home can render immediately.
        await MainActor.run {
            self.regularNewsLoadCoordinator.cancelTask(for: startOfDay)
        }

        do {
            let fetchedNeutralNews = try await FirestoreService.shared.fetchNeutralNews(for: day)

            let shouldCache = await MainActor.run {
                guard self.regularNewsLoadCoordinator.isCurrentSession(sessionID) else { return false }

                self.addNewNewsForDay(
                    neutralNews: fetchedNeutralNews,
                    regularNews: [],
                    for: startOfDay
                )
                self.markDateAsLoaded(startOfDay)
                return true
            }

            if shouldCache {
                await dayLoadGate.markLoaded(startOfDay)
                let dayInfo = DayInfo(date: dayDate)
                Task(priority: .utility) { [cacheService] in
                    cacheService.cacheNeutralNews(fetchedNeutralNews, for: dayInfo)
                }
            }
        } catch {
            print("❌ Error loading neutral news for \(dayName): \(error.localizedDescription)")

            // Fallback: try local neutral cache even if it is past the refresh TTL.
            let cachedNeutralNews = cacheService.getStaleCachedNeutralNews(for: day)

            if !cachedNeutralNews.isEmpty {
#if DEBUG
                print("🔄 Using stale neutral cache as fallback for \(dayName)")
#endif
                await MainActor.run {
                    guard self.regularNewsLoadCoordinator.isCurrentSession(sessionID) else { return }

                    self.addNewNewsForDay(
                        neutralNews: cachedNeutralNews,
                        regularNews: [],
                        for: startOfDay
                    )
                    self.markDateAsLoaded(startOfDay)
                }
                await dayLoadGate.markLoaded(startOfDay)
            }
        }

        await startRegularNewsLoad(
            for: dayDate,
            startOfDay: startOfDay,
            dayName: dayName,
            sessionID: sessionID
        )
    }

    private func startRegularNewsLoad(
        for dayDate: Date,
        startOfDay: Date,
        dayName: String,
        sessionID: UUID
    ) async {
        let regularNewsTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            do {
                let dayInfo = DayInfo(date: dayDate)
                let fetchedNews = try await FirestoreService.shared.fetchNews(for: dayInfo)

                let shouldCache = await MainActor.run {
                    guard self.regularNewsLoadCoordinator.isCurrentSession(sessionID) else {
                        self.regularNewsLoadCoordinator.removeTask(for: startOfDay)
                        return false
                    }

                    self.addNewNewsForDay(
                        neutralNews: [],
                        regularNews: fetchedNews,
                        for: startOfDay
                    )
                    self.regularNewsLoadCoordinator.removeTask(for: startOfDay)
                    return true
                }

                if shouldCache {
                    self.cacheService.cacheNews(fetchedNews, for: dayInfo)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.regularNewsLoadCoordinator.removeTask(for: startOfDay)
                }
            } catch {
                print("❌ Error loading regular news for \(dayName): \(error.localizedDescription)")

                // Fallback to stale regular cache to keep related-news lookups usable.
                let dayInfo = DayInfo(date: dayDate)
                let cachedNews = self.cacheService.getStaleCachedNews(for: dayInfo)
                guard !cachedNews.isEmpty else {
                    await MainActor.run {
                        self.regularNewsLoadCoordinator.removeTask(for: startOfDay)
                    }
                    return
                }

                await MainActor.run {
                    guard self.regularNewsLoadCoordinator.isCurrentSession(sessionID) else {
                        self.regularNewsLoadCoordinator.removeTask(for: startOfDay)
                        return
                    }

                    self.addNewNewsForDay(
                        neutralNews: [],
                        regularNews: cachedNews,
                        for: startOfDay
                    )
                    self.regularNewsLoadCoordinator.removeTask(for: startOfDay)
                }
            }
        }

        await MainActor.run {
            self.regularNewsLoadCoordinator.storeTask(regularNewsTask, for: startOfDay)
        }
    }
    
    /// Forces a refresh of news data for the specified day, bypassing the cache.
    ///
    /// Convenience method that calls `loadNews(for:forceRefresh:)` with `forceRefresh: true`.
    /// Use this when you need to ensure the latest data from Firebase.
    ///
    /// - Parameter day: The day to refresh news for
    func refreshNews(for day: DayInfo) async {
        await loadNews(for: day, forceRefresh: true)
    }

    /// Resets in-memory and cached data when the content region changes.
    ///
    /// Clears all cached news to avoid mixing regions.
    func resetForRegionChange() async {
        await dayLoadGate.reset()
        await cacheService.clearAllCache()
        await MainActor.run {
            self.regularNewsLoadCoordinator.invalidateSession()
            allNews = []
            neutralNews = []
            newsByDay = [:]
        }
    }

    func refreshTodayWidgetSnapshot() {
        exportWidgetSnapshotIfNeeded(for: Date())
    }

    /// Retrieves cached news for a specific day from memory.
    ///
    /// - Parameter dayInfo: The day to retrieve news for
    /// - Returns: A set of `NeutralNews` items for the specified day. Returns empty set if day not loaded.
    /// - Note: This method automatically cleans old data (>7 days) from memory before returning.
    func getNewsForDay(_ dayInfo: DayInfo) -> Set<NeutralNews> {
        cleanOldMemoryDataIfNeeded()
        let startOfDay = Calendar.current.startOfDay(for: dayInfo.date)
        return getNewsSetForDate(startOfDay)
    }
    
    /// Retrieves news for a specific day as a sorted array.
    ///
    /// - Parameter day: The day to retrieve news for
    /// - Returns: An array of `NeutralNews` items sorted by date (newest first). Returns empty array if day not loaded.
    func getNewsArrayForDay(_ day: DayInfo) -> [NeutralNews] {
        let newsSet = getNewsForDay(day)
        return Array(newsSet).sorted { $0.date > $1.date }
    }

    /// Retrieves all related news articles from different media sources for a neutral news item.
    ///
    /// - Parameter neutralNews: The neutral news item to find related articles for
    /// - Returns: Array of `News` items from various media outlets that are referenced in the neutral news.
    func getRelatedNews(from neutralNews: NeutralNews) -> [News] {
        neutralNews.sourceIds.compactMap { newsById[$0] }
    }

    /// Checks if news data for a specific day has been loaded into memory.
    ///
    /// - Parameter day: The day to check
    /// - Returns: `true` if the day's news is loaded, `false` otherwise.
    func isDayLoaded(_ day: DayInfo) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)
        return isDateLoaded(startOfDay)
    }
    
    /// Retrieves cache statistics for debugging and monitoring.
    ///
    /// - Returns: A tuple containing:
    ///   - `memory`: Number of days currently loaded in memory
    ///   - `persistent`: Tuple with counts of cached neutral news and regular news in SwiftData
    func getCacheStats() -> (memory: Int, persistent: (neutralNews: Int, news: Int)) {
        let memoryCount = newsByDay.count
        let persistentStats = cacheService.getCacheStats()
        return (memory: memoryCount, persistent: persistentStats)
    }

    /// Pre-loads today's news into cache if not already cached.
    ///
    /// Call this method on app launch to ensure today's data is available immediately.
    /// Skips loading if today's cache is already valid.
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

    /// Starts progressive background loading of recent days' news.
    ///
    /// Loads the last 6 days (premium users) or 1 day (free users) in the background
    /// with staggered delays to avoid network congestion. Uses cache-first strategy
    /// for faster loading.
    ///
    /// - Note: This method is idempotent - calling it multiple times won't start duplicate tasks.
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
        // Add only truly new neutral news with O(n) ID lookups.
        let existingNeutralIDs = Set(neutralNews.map(\.id))
        let newNeutralNews = fetchedNeutralNews.filter { !existingNeutralIDs.contains($0.id) }
        
        if !newNeutralNews.isEmpty {
            self.neutralNews.append(contentsOf: newNeutralNews)
            self.addNewsToDay(newNeutralNews, for: date)
        }

        if !fetchedNeutralNews.isEmpty {
            exportWidgetSnapshotIfNeeded(for: date)
        }
        
        // Add only truly new regular news with O(n) ID lookups.
        let existingNewsIDs = Set(allNews.map(\.id))
        let newNews = fetchedNews.filter { !existingNewsIDs.contains($0.id) }
        
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
        let existingNeutralIDs = Set(neutralNews.map(\.id))
        let newNeutralNews = fetchedNeutralNews.filter { !existingNeutralIDs.contains($0.id) }
        
        if !newNeutralNews.isEmpty {
            neutralNews.append(contentsOf: newNeutralNews)
        }
        
        // Step 3: Update the day collection with fresh data
        ensureNewsSetExists(for: date)
        setNewsForDate(Set(fetchedNeutralNews), date: date)
        exportWidgetSnapshotIfNeeded(for: date)
        
        // Step 4: Handle regular news similarly
        let fetchedNewsDict = Dictionary(uniqueKeysWithValues: fetchedNews.map { ($0.id, $0) })
        
        // Update existing items
        for i in allNews.indices {
            if let freshNews = fetchedNewsDict[allNews[i].id] {
                allNews[i] = freshNews
            }
        }
        
        // Add only genuinely new items that don't exist yet
        let existingNewsIDs = Set(allNews.map(\.id))
        let newNews = fetchedNews.filter { !existingNewsIDs.contains($0.id) }
        
        if !newNews.isEmpty {
            allNews.append(contentsOf: newNews)
        }
    }
    
    private func addNewsToDay(_ news: [NeutralNews], for date: Date) {
        addNewsToDate(Set(news), date: date)
    }

    private func exportWidgetSnapshotIfNeeded(for date: Date) {
        guard Calendar.current.isDateInToday(date) else { return }

        let todayNews = getNewsArrayForDay(.today)
        let region = ContentRegionProvider().currentRegion.rawValue
        guard let snapshot = WidgetBriefingBuilder.buildSnapshot(from: todayNews, region: region) else { return }

        Task(priority: .utility) { [widgetSnapshotStore] in
            do {
                let didWriteSnapshot = try widgetSnapshotStore.writeSnapshot(snapshot)
                if didWriteSnapshot {
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotConstants.widgetKind)
                }
            } catch {
#if DEBUG
                print("Failed to export widget snapshot: \(error.localizedDescription)")
#endif
            }
        }
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
        }

        Task { [dayLoadGate] in
            await dayLoadGate.removeLoadedDates(oldDates)
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
