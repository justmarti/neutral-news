//
//  NewsQuestionAnswer.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/7/26.
//

import Foundation

struct NewsQuestionAnswer: Equatable, Sendable {
    let text: String
    let referencedSources: [String]
}
