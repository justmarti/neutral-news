//
//  NewsFilterViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation

enum SearchScope: CaseIterable {
    case daySelected
    case lastSevenDays
}

@Observable
final class NewsFilterViewModel {
    static let shared = NewsFilterViewModel()
    
    // MARK: - Dependencies
    private let newsDataManager = NewsDataManager.shared
    
    // MARK: - Filter Change Callback
    var onFiltersChanged: (() -> Void)?
    private var debounceTask: Task<Void, Never>?
    
    // MARK: - Properties
    var searchText: String = "" {
        didSet {
            if searchText.isEmpty {
                searchScope = .daySelected
            }
            debounceFilterChange()
        }
    }
    
    var searchScope: SearchScope = .daySelected {
        didSet {
            debounceFilterChange()
        }
    }
    
    var categoryFilter: Set<Category> = [] {
        didSet {
            debounceFilterChange()
        }
    }
    
    var orderBy: OrderBy = .hour {
        didSet {
            debounceFilterChange()
        }
    }
    
    // MARK: - Computed Properties
    var isAnyFilterEnabled: Bool {
        !categoryFilter.isEmpty
    }
    
    // MARK: - Public Methods
    
    func applyFilters(to news: [NeutralNews], daySelected: DayInfo? = nil) -> [NeutralNews] {
        // Early return for empty input
        guard !news.isEmpty else { return [] }
        
        var filteredNews = news
        
        // Apply search scope filter
        if searchScope == .daySelected, let daySelected = daySelected {
            let targetDate = daySelected.date
            filteredNews = filteredNews.filter { newsItem in
                Calendar.current.isDate(newsItem.date, inSameDayAs: targetDate)
            }
        }
        
        // Apply category filter
        if !categoryFilter.isEmpty {
            let normalizedCategories = Set(categoryFilter.map { $0.rawValue.normalized() })
            filteredNews = filteredNews.filter { newsItem in
                normalizedCategories.contains(newsItem.category.normalized())
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            let normalizedQuery = searchText.normalizedSearchString()
            filteredNews = filteredNews.filter { newsItem in
                newsItem.neutralTitle.normalizedSearchString().contains(normalizedQuery) ||
                newsItem.neutralDescription.normalizedSearchString().contains(normalizedQuery)
            }
        }
        
        // Apply sorting
        return sortNews(filteredNews)
    }
    
    func filterByCategory(_ category: Category) {
        if categoryFilter.contains(category) {
            categoryFilter.remove(category)
        } else {
            categoryFilter.insert(category)
        }
    }
    
    func clearFilters() {
        categoryFilter.removeAll()
    }
    
    func resetToDefaults() {
        categoryFilter.removeAll()
        searchText = ""
        searchScope = .daySelected
        orderBy = .hour
    }
    
    // MARK: - Private Methods
    
    private func debounceFilterChange() {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                onFiltersChanged?()
            }
        }
    }
    
    private func sortNews(_ news: [NeutralNews]) -> [NeutralNews] {
        // Pre-compute popularity scores to avoid expensive calls during sorting
        let popularityCache: [String: Int] = {
            guard orderBy == .popularity else { return [:] }
            var cache: [String: Int] = [:]
            for newsItem in news {
                cache[newsItem.id] = newsDataManager.getRelatedNews(from: newsItem).count
            }
            return cache
        }()
        
        return news.sorted { (news1: NeutralNews, news2: NeutralNews) -> Bool in
            // Prioritize search matches in titles
            if !searchText.isEmpty {
                let normalizedQuery = searchText.normalizedSearchString()
                let title1ContainsQuery = news1.neutralTitle.normalizedSearchString().contains(normalizedQuery)
                let title2ContainsQuery = news2.neutralTitle.normalizedSearchString().contains(normalizedQuery)
                
                if title1ContainsQuery && !title2ContainsQuery {
                    return true
                } else if !title1ContainsQuery && title2ContainsQuery {
                    return false
                }
            }
            
            // Apply order by
            switch orderBy {
            case .hour:
                return news1.date > news2.date
            case .relevance:
                return news1.relevance > news2.relevance
            case .popularity:
                let count1 = popularityCache[news1.id] ?? 0
                let count2 = popularityCache[news2.id] ?? 0
                return count1 > count2
            }
        }
    }
}
