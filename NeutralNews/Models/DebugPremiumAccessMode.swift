//
//  DebugPremiumAccessMode.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 7/28/26.
//

#if DEBUG
enum DebugPremiumAccessMode: String, CaseIterable, Identifiable {
    case revenueCat
    case forceFree
    case forcePro

    var id: Self {
        self
    }

    func resolvesAccess(revenueCatIsPremium: Bool) -> Bool {
        switch self {
        case .revenueCat:
            revenueCatIsPremium
        case .forceFree:
            false
        case .forcePro:
            true
        }
    }
}
#endif
