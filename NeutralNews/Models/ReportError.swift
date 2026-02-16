//
//  ReportError.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import Foundation

enum ReportError: Equatable {
    case cooldown(remainingTime: String)
    case networkError
    case firebaseError
    case permissionDenied
    case unknown
    
    var title: LocalizedStringResource {
        switch self {
        case .cooldown: "Wait a moment"
        case .networkError: "No connection"
        case .firebaseError: "Server error"
        case .permissionDenied: "Permission denied"
        case .unknown: "Unexpected error"
        }
    }
    
    var description: LocalizedStringResource {
        switch self {
        case .cooldown(let time): "You can send another report in \(time)."
        case .networkError: "Check your internet connection and try again."
        case .firebaseError: "There was a problem with the server. Try again later."
        case .permissionDenied: "You don’t have permission to send reports."
        case .unknown: "Something went wrong. Try again."
        }
    }
    
    var systemImage: String {
        switch self {
        case .cooldown:
            return "clock.fill"
        case .networkError:
            return "wifi.slash"
        case .firebaseError:
            return "server.rack"
        case .permissionDenied:
            return "lock.fill"
        case .unknown:
            return "exclamationmark.triangle.fill"
        }
    }
    
    static func from(_ error: Error) -> ReportError {
        if let firestoreError = error as NSError? {
            switch firestoreError.code {
            case 7: // Permission denied
                return .permissionDenied
            case 14: // Unavailable (network issues)
                return .networkError
            default:
                return .firebaseError
            }
        }
        return .unknown
    }
}
