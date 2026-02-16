//
//  Category.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 1/5/25.
//

import Foundation

enum Category: String, CaseIterable, Decodable, Hashable {
    case politics
    case business
    case world
    case technology
    case science
    case health
    case sports
    case culture
    case entertainment
    case society

    var title: LocalizedStringResource {
        switch self {
        case .politics: "Politics"
        case .business: "Business"
        case .world: "World"
        case .technology: "Technology"
        case .science: "Science"
        case .health: "Health"
        case .sports: "Sports"
        case .culture: "Culture"
        case .entertainment: "Entertainment"
        case .society: "Society"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .politics: return "building.columns"
        case .business: return "eurosign.circle"
        case .world: return "globe"
        case .technology: return "cpu"
        case .science: return "atom"
        case .health: return "heart"
        case .sports: return "sportscourt"
        case .culture: return "book"
        case .entertainment: return "popcorn"
        case .society: return "person.2"
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
        case .business:
            return ["economia", "economy", "business", "finance", "finanzas"]
        case .world:
            return ["internacional", "international", "world"]
        case .technology:
            return ["tecnologia", "technology", "tech"]
        case .science:
            return ["ciencia", "science", "medio-ambiente", "medioambiente", "environment"]
        case .health:
            return ["salud", "health"]
        case .sports:
            return ["deportes", "sports", "sport"]
        case .culture:
            return ["cultura", "culture"]
        case .entertainment:
            return ["entretenimiento", "entertainment"]
        case .society:
            return [
                "sociedad", "society", "nacional", "national",
                "educacion", "education", "sucesos", "crime",
                "opinion", "other", "otros", "sincategoria",
                "sin-categoria", "uncategorized"
            ]
        }
    }
}
