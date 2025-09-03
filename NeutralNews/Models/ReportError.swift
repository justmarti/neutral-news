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
    
    var title: String {
        switch self {
        case .cooldown:
            return "Espera un momento"
        case .networkError:
            return "Sin conexión"
        case .firebaseError:
            return "Error del servidor"
        case .permissionDenied:
            return "Sin permisos"
        case .unknown:
            return "Error inesperado"
        }
    }
    
    var description: String {
        switch self {
        case .cooldown(let time):
            return "Puedes enviar otro reporte en \(time)"
        case .networkError:
            return "Revisa tu conexión a internet e inténtalo de nuevo"
        case .firebaseError:
            return "Hubo un problema con el servidor. Inténtalo más tarde"
        case .permissionDenied:
            return "No tienes permisos para enviar reportes"
        case .unknown:
            return "Algo salió mal. Inténtalo de nuevo"
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
