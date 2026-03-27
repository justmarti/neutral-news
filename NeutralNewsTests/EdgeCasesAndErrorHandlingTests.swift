//
//  EdgeCasesAndErrorHandlingTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import Testing
@testable import NeutralNews

@Suite("Model and Normalization Tests")
struct ModelAndNormalizationTests {

    @Test("DayInfo equality and hashing use the calendar day instead of the exact time")
    func dayInfoEqualityAndHashingUseTheCalendarDay() {
        let calendar = Calendar.current
        let morning = calendar.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 8))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 21))!

        let morningInfo = DayInfo(date: morning)
        let eveningInfo = DayInfo(date: evening)

        #expect(morningInfo == eveningInfo)
        #expect(Set([morningInfo, eveningInfo]).count == 1)
    }

    @Test("Category aliases remain supported for legacy backend values")
    func categoryAliasesRemainSupportedForLegacyBackendValues() {
        #expect(Category.fromBackendValue("politica") == .politics)
        #expect(Category.fromBackendValue("economia") == .business)
        #expect(Category.fromBackendValue("tecnologia") == .technology)
        #expect(Category.fromBackendValue("medio_ambiente") == .science)
        #expect(Category.fromBackendValue("sin categoría") == .society)
    }

    @Test("Unknown backend categories are rejected")
    func unknownBackendCategoriesAreRejected() {
        #expect(Category.fromBackendValue("totally-unknown-category") == nil)
    }

    @Test("Search normalization removes accents and punctuation")
    func searchNormalizationRemovesAccentsAndPunctuation() {
        let normalized = "¡Política, economía y opinión!".normalizedSearchString()

        #expect(normalized == "politica economia y opinion")
    }
}
