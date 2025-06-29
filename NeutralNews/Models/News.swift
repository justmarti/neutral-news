//
//  News.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import Foundation

struct News: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
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
    var neutralScore: Int
    var group: Int
    var embedding: [Double]
    
    static func == (lhs: News, rhs: News) -> Bool {
        lhs.link == rhs.link && lhs.group == rhs.group
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(link)
        hasher.combine(group)
    }
    
    static let mock = News(
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
