//
//  News.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import Foundation

struct News: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let scrappedDescription: String?
    let category: String
    let imageUrl: String?
    let link: String
    let pubDate: Date
    let createdAt: Date
    let updatedAt: Date
    let sourceMedium: Media
    let neutralScore: Int
    let group: Int
    let embedding: [Double]
    
    static func == (lhs: News, rhs: News) -> Bool {
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
    
    static let mock = News(
        id: "mock-id",
        title: "Lorem ipsum dolor sit amet",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        scrappedDescription: nil,
        category: Category.politica.rawValue,
        imageUrl: "https://www.lavanguardia.com/files/og_thumbnail/files/fp/uploads/2025/04/22/68075b725f598.r_d.1714-2017-0.jpeg",
        link: "itram.dev",
        pubDate: .now,
        createdAt: .now,
        updatedAt: .now,
        sourceMedium: .abc,
        neutralScore: 50,
        group: 0,
        embedding: []
    )
}
