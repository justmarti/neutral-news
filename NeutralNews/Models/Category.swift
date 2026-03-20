//
//  Category.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 1/5/25.
//

import Foundation

enum Category: String, CaseIterable, Decodable, Hashable {
    case politics
    case world
    case business
    case technology
    case science
    case health
    case society
    case culture
    case sports
    case entertainment

    var title: LocalizedStringResource {
        switch self {
        case .politics: "Politics"
        case .world: "World"
        case .business: "Business"
        case .technology: "Technology"
        case .science: "Science"
        case .health: "Health"
        case .society: "Society"
        case .culture: "Culture"
        case .sports: "Sports"
        case .entertainment: "Entertainment"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .politics: return "building.columns"
        case .world: return "globe"
        case .business: return "chart.line.uptrend.xyaxis"
        case .technology: return "cpu"
        case .science: return "atom"
        case .health: return "heart"
        case .society: return "person.2"
        case .culture: return "book"
        case .sports: return "sportscourt"
        case .entertainment: return "popcorn"
        }
    }

    // Accepts canonical category IDs and legacy labels from existing Firestore data.
    static func fromBackendValue(_ value: String) -> Category? {
        let normalizedValue = value
            .normalized()
            .replacingOccurrences(of: "_", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let directMatch = Category(rawValue: normalizedValue) {
            return directMatch
        }

        for category in Category.allCases where category.backendAliases.contains(normalizedValue) {
            return category
        }

        return nil
    }

    static func displayName(for backendValue: String) -> String {
        guard let category = fromBackendValue(backendValue) else {
            return backendValue
        }
        return String(localized: category.title)
    }

    // Legacy aliases kept for backward compatibility with old backend values.
    // Safe to remove once backend writes canonical category IDs only and old values
    // are no longer present in Firestore/cache for at least one full TTL window.
    private var backendAliases: Set<String> {
        switch self {
        case .politics:
            return ["politica", "politics", "politic"]
        case .world:
            return ["internacional", "international", "world"]
        case .business:
            return ["economia", "economy", "business", "finance", "finanzas"]
        case .technology:
            return ["tecnologia", "technology", "tech"]
        case .science:
            return ["ciencia", "science", "medio-ambiente", "medioambiente", "environment"]
        case .health:
            return ["salud", "health"]
        case .society:
            return [
                "sociedad", "society", "nacional", "national",
                "educacion", "education", "sucesos", "crime",
                "opinion", "other", "otros", "sincategoria",
                "sin-categoria", "uncategorized"
            ]
        case .culture:
            return ["cultura", "culture"]
        case .sports:
            return ["deportes", "sports", "sport"]
        case .entertainment:
            return ["entretenimiento", "entertainment"]
        }
    }
}
