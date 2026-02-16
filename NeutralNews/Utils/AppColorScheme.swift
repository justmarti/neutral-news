//
//  AppColorScheme.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 6/2/2026.
//

import SwiftUI

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "app_color_scheme"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
