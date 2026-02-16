//
//  Problem.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

enum Problem: String, CaseIterable {
    case newsRepeated = "news_repeated"
    case notRelatedNews = "not_related_news"
    case wrongInformation = "wrong_information"
    case offensiveLanguage = "offensive_language"
    
    var title: LocalizedStringResource {
        switch self {
        case .newsRepeated: "Duplicate article"
        case .notRelatedNews: "Unrelated article"
        case .wrongInformation: "Incorrect information"
        case .offensiveLanguage: "Offensive language"
        }
    }
    
    var description: LocalizedStringResource {
        switch self {
        case .newsRepeated: "This story already appears in another section or day"
        case .notRelatedNews: "There is an unrelated article below"
        case .wrongInformation: "The displayed information contains errors"
        case .offensiveLanguage: "The content includes inappropriate language"
        }
    }
    
    var systemImage: String {
        switch self {
        case .newsRepeated:
            return "doc.on.doc"
        case .notRelatedNews:
            return "questionmark.circle"
        case .wrongInformation:
            return "exclamationmark.triangle"
        case .offensiveLanguage:
            return "hand.raised"
        }
    }
    
    var color: Color {
        switch self {
        case .newsRepeated:
            return .orange
        case .notRelatedNews:
            return .blue
        case .wrongInformation:
            return .red
        case .offensiveLanguage:
            return .purple
        }
    }
}
