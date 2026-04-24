//
//  StoryFeedState.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/28/26.
//

import Foundation

enum StoryFeedState {
    static func adjustedIndex(
        currentIndex: Int,
        previousIDs: [String],
        newIDs: [String]
    ) -> Int {
        guard !newIDs.isEmpty else { return 0 }

        let boundedCurrentIndex = max(currentIndex, 0)

        guard !previousIDs.isEmpty else {
            return min(boundedCurrentIndex, newIDs.count - 1)
        }

        if boundedCurrentIndex < previousIDs.count {
            let currentID = previousIDs[boundedCurrentIndex]
            if let preservedIndex = newIDs.firstIndex(of: currentID) {
                return preservedIndex
            }
        }

        return min(boundedCurrentIndex, newIDs.count - 1)
    }
}
