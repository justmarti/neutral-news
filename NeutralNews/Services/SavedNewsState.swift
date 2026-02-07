//
//  SavedNewsState.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 7/2/26.
//

import Foundation
import Observation
import CoreData

@Observable
final class SavedNewsState {
    static let shared = SavedNewsState()

    private(set) var savedById: [String: Bool] = [:]

    private init() {}

    func isSaved(_ newsId: String) -> Bool {
        savedById[newsId] ?? false
    }

    @MainActor
    func setSaved(_ isSaved: Bool, for newsId: String) {
        savedById[newsId] = isSaved
    }

    @MainActor
    func ensureCached(newsId: String, context: NSManagedObjectContext) {
        guard savedById[newsId] == nil else { return }
        let isSaved = SavedNewsService.shared.isNewsSaved(newsId: newsId, context: context)
        savedById[newsId] = isSaved
    }
}
