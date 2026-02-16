//
//  ContentRegionProvider.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 6/2/2026.
//

import Foundation

enum ContentRegion: String {
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
            #if DEBUG
            print("🌍 Content region detected: ES")
            #endif
            return .es
        case ContentRegion.us.rawValue:
            #if DEBUG
            print("🌍 Content region detected: US")
            #endif
            return .us
        default:
            #if DEBUG
            print("🌍 Content region detected: fallback US (raw: \(regionCode ?? "nil"))")
            #endif
            return .us
        }
    }
}
