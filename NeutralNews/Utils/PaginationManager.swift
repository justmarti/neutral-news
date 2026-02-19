//
//  PaginationManager.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 4/9/25.
//

import Foundation

@Observable
final class PaginationManager<Item: Identifiable> {
    
    // MARK: - Configuration
    static var defaultPageSize: Int { 30 }
    
    // MARK: - State
    private(set) var paginatedItems: [Item] = []
    private(set) var currentPage = 0
    private(set) var isLoading = false
    private(set) var hasMorePages = true
    var totalItemCount: Int { cachedAllItems.count }
    
    // MARK: - Private Properties
    private let pageSize: Int
    private let preloadMargin: Int
    private var cachedAllItems: [Item] = []
    private var lastDataHash: Int = 0
    
    // MARK: - Initialization
    init(pageSize: Int = defaultPageSize, preloadMargin: Int = 5) {
        self.pageSize = pageSize
        self.preloadMargin = max(1, preloadMargin)
    }
    
    // MARK: - Public Methods
    
    func configure(with allItems: [Item]) {
        let newHash = hashForItems(allItems) 
        guard newHash != lastDataHash else { return } // Avoid unnecessary recalculations
        
        cachedAllItems = allItems
        lastDataHash = newHash
        reset()
        loadInitialPage()
    }
    
    func reconfigure(with newFilteredItems: [Item]) {
        // Force reconfiguration for filter changes (always update)
        cachedAllItems = newFilteredItems
        lastDataHash = hashForItems(newFilteredItems)
        reset()
        loadInitialPage()
    }
    
    func loadNextPage() {
        guard hasMorePages && !isLoading else { return }
        
        isLoading = true
        
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, cachedAllItems.count)
        
        guard startIndex < cachedAllItems.count else {
            hasMorePages = false
            isLoading = false
            return
        }
        
        let newItems = Array(cachedAllItems[startIndex..<endIndex])
        paginatedItems.append(contentsOf: newItems)
        currentPage += 1
        
        hasMorePages = endIndex < cachedAllItems.count
        isLoading = false
    }
    
    func shouldLoadMore(for item: Item) -> Bool {
        guard hasMorePages && !isLoading else { return false }
        guard let currentIndex = paginatedItems.firstIndex(where: { $0.id == item.id }) else { return false }

        let thresholdIndex = max(0, paginatedItems.count - preloadMargin)
        return currentIndex >= thresholdIndex
    }
    
    func reset() {
        paginatedItems.removeAll()
        currentPage = 0
        hasMorePages = true
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func hashForItems(_ items: [Item]) -> Int {
        // More sophisticated hash that includes count + first few IDs
        var hasher = Hasher()
        hasher.combine(items.count)
        
        // Include first 3 item IDs for better hash precision
        for item in items.prefix(3) {
            hasher.combine(item.id)
        }
        
        return hasher.finalize()
    }
    
    private func loadInitialPage() {
        guard hasMorePages && !isLoading else { return }
        
        let endIndex = min(pageSize, cachedAllItems.count)
        
        guard endIndex > 0 else {
            hasMorePages = false
            return
        }
        
        paginatedItems = Array(cachedAllItems[0..<endIndex])
        currentPage = 1
        hasMorePages = endIndex < cachedAllItems.count
    }
}

// MARK: - Error Handling
extension PaginationManager {
    enum PaginationError: Error, LocalizedError {
        case dataSourceEmpty
        case invalidPageIndex
        
        var errorDescription: String? {
            switch self {
            case .dataSourceEmpty:
                return "No hay datos disponibles para paginar"
            case .invalidPageIndex:
                return "Índice de página inválido"
            }
        }
    }
}
