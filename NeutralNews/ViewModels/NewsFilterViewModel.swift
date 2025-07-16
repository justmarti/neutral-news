//
//  NewsFilterViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftUI

enum SearchScope: CaseIterable {
    case daySelected
    case lastSevenDays
}

@Observable
final class NewsFilterViewModel {
    static let shared = NewsFilterViewModel()
    
    private init() {
        print("🔫 NewsFilterViewModel initialized")
    }
    
    // MARK: - Dependencies
    private let newsDataManager = NewsDataManager.shared
    
    // MARK: - Properties
    var searchText: String = "" {
        didSet {
            if searchText.isEmpty {
                searchScope = .daySelected
            }
        }
    }
    var searchScope: SearchScope = .daySelected
    var categoryFilter: Set<Category> = []
    var orderBy: OrderBy = .hour
    
    // MARK: - Computed Properties
    var isAnyFilterEnabled: Bool {
        !categoryFilter.isEmpty
    }
    
    // MARK: - Public Methods
    
    func applyFilters(to news: [NeutralNews], daySelected: DayInfo? = nil) -> [NeutralNews] {
        var filteredNews = news
        
        // Apply search scope filter
        if searchScope == .daySelected, let daySelected = daySelected {
            filteredNews = filteredNews.filter { news in
                Calendar.current.isDate(news.date, inSameDayAs: daySelected.date)
            }
        }
        // If searchScope is .lastSevenDays, use all news (no date filtering)
        
        // Apply category filter
        if !categoryFilter.isEmpty {
            filteredNews = filteredNews.filter { news in
                categoryFilter.contains { category in
                    news.category.normalized() == category.rawValue.normalized()
                }
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            let normalizedQuery = searchText.normalizedSearchString()
            filteredNews = filteredNews.filter {
                $0.neutralTitle.normalizedSearchString().contains(normalizedQuery) ||
                $0.neutralDescription.normalizedSearchString().contains(normalizedQuery)
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
    
    // MARK: - Private Methods
    
    private func sortNews(_ news: [NeutralNews]) -> [NeutralNews] {
        return news.sorted { news1, news2 in
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
                let relatedNews1Count = newsDataManager.getRelatedNews(from: news1).count
                let relatedNews2Count = newsDataManager.getRelatedNews(from: news2).count
                return relatedNews1Count > relatedNews2Count
            }
        }
    }
}
