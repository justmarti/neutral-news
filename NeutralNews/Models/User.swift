//
//  User.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/20/25.
//

import Foundation
import FirebaseAuth

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let displayName: String?
    let createdAt: Date

    init(id: String, email: String, displayName: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
    }

    init?(from firebaseUser: FirebaseAuth.User) {
        self.id = firebaseUser.uid
        self.email = firebaseUser.email ?? ""
        self.displayName = firebaseUser.displayName
        self.createdAt = firebaseUser.metadata.creationDate ?? Date()
    }
}