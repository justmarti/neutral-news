//
//  StoryFeedStateTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 3/28/26.
//

import Testing
@testable import NeutralNews

@Suite("Story Feed State Tests")
struct StoryFeedStateTests {
    @Test("Adjusted index resets to zero when the new dataset is empty")
    func adjustedIndexResetsToZeroWhenNewDatasetIsEmpty() {
        let adjustedIndex = StoryFeedState.adjustedIndex(
            currentIndex: 3,
            previousIDs: ["one", "two", "three", "four"],
            newIDs: []
        )

        #expect(adjustedIndex == 0)
    }

    @Test("Adjusted index preserves the current story when it still exists after refresh")
    func adjustedIndexPreservesCurrentStoryWhenItStillExists() {
        let adjustedIndex = StoryFeedState.adjustedIndex(
            currentIndex: 1,
            previousIDs: ["alpha", "beta", "gamma"],
            newIDs: ["gamma", "beta", "delta", "alpha"]
        )

        #expect(adjustedIndex == 1)
    }

    @Test("Adjusted index clamps to the last available story when the current one disappears")
    func adjustedIndexClampsToLastAvailableStoryWhenCurrentStoryDisappears() {
        let adjustedIndex = StoryFeedState.adjustedIndex(
            currentIndex: 4,
            previousIDs: ["one", "two", "three", "four", "five"],
            newIDs: ["one", "two"]
        )

        #expect(adjustedIndex == 1)
    }
}
