//
//  SavedNewsState.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 7/2/26.
//

import Foundation
import Observation

@Observable
final class SavedNewsState {
    static let shared = SavedNewsState()

    private(set) var savedById: [String: Bool] = [:]

    private init() {}

    func isSaved(_ newsId: String) -> Bool {
        savedById[newsId] ?? false
    }

    func hasStatus(for newsId: String) -> Bool {
        savedById[newsId] != nil
    }

    @MainActor
    func setSaved(_ isSaved: Bool, for newsId: String) {
        savedById[newsId] = isSaved
    }

    @MainActor
    func markSaved(newsIds: [String]) {
        guard !newsIds.isEmpty else { return }

        savedById.reserveCapacity(max(savedById.count, newsIds.count))
        for newsId in newsIds {
            savedById[newsId] = true
        }
    }
}
