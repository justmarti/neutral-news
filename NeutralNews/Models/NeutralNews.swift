//
//  NeutralNews.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 13/4/25.
//

import Foundation

struct StoryCrop: Codable, Hashable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var centerX: Double {
        x + (width / 2)
    }

    var centerY: Double {
        y + (height / 2)
    }

    var focusPoint: StoryFocusPoint {
        StoryFocusPoint(x: centerX, y: centerY)
    }
}

struct StoryFocusPoint: Codable, Hashable, Sendable {
    let x: Double
    let y: Double
}

struct NeutralNews: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let neutralTitle: String
    let neutralDescription: String
    let category: String
    let relevance: Int
    let imageUrl: String
    let imageMedium: String
    let date: Date
    let createdAt: Date
    let updatedAt: Date
    let group: Int
    let sourceIds: [String]
    let storyFocusPoint: StoryFocusPoint?
    
    static func == (lhs: NeutralNews, rhs: NeutralNews) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = json as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return dictionary
    }
    
    static let mock = NeutralNews(
        id: "mock-id",
        neutralTitle: "Lorem ipsum dolor sit amet",
        neutralDescription: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        category: Category.business.rawValue,
        relevance: 3,
        imageUrl: "https://www.lavanguardia.com/files/og_thumbnail/files/fp/uploads/2025/04/22/68075b725f598.r_d.1714-2017-0.jpeg",
        imageMedium: "laVanguardia",
        date: .now,
        createdAt: .now,
        updatedAt: .now,
        group: 0,
        sourceIds: ["mock-news-1", "mock-news-2"],
        storyFocusPoint: nil
    )
}
