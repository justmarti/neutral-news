//
//  NewsListViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftUI

@Observable
final class NewsListViewModel {
    
    // MARK: - Dependencies
    private let newsDataManager = NewsDataManager.shared
    private let filterViewModel = NewsFilterViewModel()
    
    // MARK: - UI State
    var daySelected: DayInfo = .today {
        didSet {
            if daySelected != oldValue {
                loadNewsForSelectedDay()
            }
        }
    }
    
    var isLoadingNeutralNews = false
    
    // MARK: - Computed Properties
    var lastSevenDays: [DayInfo] {
        newsDataManager.lastSevenDays
    }
    
    var newsToShow: [NeutralNews] {
        let newsToFilter = filterViewModel.searchScope == .daySelected 
            ? newsDataManager.getNewsArrayForDay(daySelected)
            : Array(Set(newsDataManager.neutralNews)).sorted { $0.date > $1.date }
        return filterViewModel.applyFilters(to: newsToFilter, daySelected: daySelected)
    }
    
    var searchText: String {
        get { filterViewModel.searchText }
        set { 
            withAnimation {
                filterViewModel.searchText = newValue
            }
        }
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
    
    // MARK: - Initialization
    init() {
        loadNewsForSelectedDay()
        
        // Pre-load cache in background
        Task {
            await newsDataManager.preloadCache()
        }
    }
    
    // MARK: - Public Methods
    
    func changeDay(to dayInfo: DayInfo) {
        daySelected = dayInfo
    }
    
    func getRelatedNews(from neutralNews: NeutralNews) -> [News] {
        newsDataManager.getRelatedNews(from: neutralNews)
    }
    
    func getCategoriesOfTheDay() -> [Category] {
        let dayNews = newsDataManager.getNewsArrayForDay(daySelected)
        let categoriesSet = dayNews.compactMap { Category(rawValue: $0.category) }
        return Category.allCases.filter { categoriesSet.contains($0) }
    }
    
    func refreshNews() async {
        await newsDataManager.refreshNews(for: daySelected)
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
}
