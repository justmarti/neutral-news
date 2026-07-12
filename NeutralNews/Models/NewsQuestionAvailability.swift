//
//  NewsQuestionAvailability.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/7/26.
//

import Foundation

enum NewsQuestionAvailability: Equatable, Sendable {
    case available
    case appleIntelligenceNotEnabled
    case modelNotReady
    case deviceNotEligible
    case unavailable

    @MainActor
    static var current: NewsQuestionAvailability {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            NewsQuestionFoundationModelsService.availability
        } else {
            .unavailable
        }
#else
        .unavailable
#endif
    }
}
