//
//  UserDefaultsExtensions.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/07/25.
//

import Foundation

extension UserDefaults {
    private static let hasSeenOnboardingKey = "hasSeenOnboarding"
    
    static var hasSeenOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasSeenOnboardingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasSeenOnboardingKey)
        }
    }
}