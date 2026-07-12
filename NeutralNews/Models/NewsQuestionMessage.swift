//
//  NewsQuestionMessage.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/7/26.
//

import Foundation

struct NewsQuestionMessage: Identifiable, Equatable, Sendable {
    enum Role: Equatable, Sendable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
    let referencedSources: [String]

    init(role: Role, text: String, referencedSources: [String] = []) {
        self.role = role
        self.text = text
        self.referencedSources = referencedSources
    }
}
