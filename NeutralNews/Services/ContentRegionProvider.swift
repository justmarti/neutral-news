//
//  ContentRegionProvider.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 6/2/2026.
//

import Foundation

enum ContentRegion: String, Sendable {
    case us = "US"
    case es = "ES"
}

enum ContentRegionPreference: String, CaseIterable, Identifiable {
    case automatic
    case us
    case es

    static let storageKey = "content_region_preference"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .automatic:
            return "Automatic"
        case .us:
            return "United States"
        case .es:
            return "Spain"
        }
    }
}

protocol ContentRegionProviding {
    var currentRegion: ContentRegion { get }
}

struct ContentRegionProvider: ContentRegionProviding {
    var currentRegion: ContentRegion {
        let preferenceRaw = UserDefaults.standard.string(forKey: ContentRegionPreference.storageKey)
        WidgetRegionPreferenceStore.syncPreference(rawValue: preferenceRaw)
        let preference = ContentRegionPreference(rawValue: preferenceRaw ?? ContentRegionPreference.automatic.rawValue) ?? .automatic

        switch preference {
        case .us:
            return .us
        case .es:
            return .es
        case .automatic:
            break
        }

        let regionCode: String?
        
        if #available(iOS 16.0, *) {
            regionCode = Locale.autoupdatingCurrent.region?.identifier
        } else {
            regionCode = Locale.autoupdatingCurrent.regionCode
        }
        
        switch regionCode?.uppercased() {
        case ContentRegion.es.rawValue:
            return .es
        case ContentRegion.us.rawValue:
            return .us
        default:
            return .us
        }
    }
}
