//
//  SavedNewsState.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 7/2/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SavedNewsState {
    static let shared = SavedNewsState()

    private(set) var savedById: [String: Bool] = [:]
    private let regionProvider: ContentRegionProviding

    private init(regionProvider: ContentRegionProviding = ContentRegionProvider()) {
        self.regionProvider = regionProvider
    }

    private func scopedKey(newsId: String, regionRaw: String?) -> String {
        let resolvedRegionRaw = regionRaw ?? regionProvider.currentRegion.rawValue
        return "\(resolvedRegionRaw)|\(newsId)"
    }

    func isSaved(_ newsId: String, regionRaw: String? = nil) -> Bool {
        let key = scopedKey(newsId: newsId, regionRaw: regionRaw)
        return savedById[key] ?? false
    }

    func hasStatus(for newsId: String, regionRaw: String? = nil) -> Bool {
        let key = scopedKey(newsId: newsId, regionRaw: regionRaw)
        return savedById[key] != nil
    }

    func setSaved(_ isSaved: Bool, for newsId: String, regionRaw: String? = nil) {
        let key = scopedKey(newsId: newsId, regionRaw: regionRaw)
        savedById[key] = isSaved
    }

    func markSaved(newsIds: [String], regionRaw: String? = nil) {
        guard !newsIds.isEmpty else { return }

        savedById.reserveCapacity(max(savedById.count, newsIds.count))
        for newsId in newsIds {
            let key = scopedKey(newsId: newsId, regionRaw: regionRaw)
            savedById[key] = true
        }
    }
}
