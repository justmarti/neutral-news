//
//  Problem.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

enum Problem: String, CaseIterable {
    case newsRepeated = "Noticia repetida"
    case notRelatedNews = "Noticia no relacionada"
    case wrongInformation = "Información incorrecta"
    case offensiveLanguage = "Lenguaje ofensivo"
    
    var title: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .newsRepeated:
            return "Esta noticia ya aparece en otra sección o día"
        case .notRelatedNews:
            return "Hay alguna noticia no relacionada abajo"
        case .wrongInformation:
            return "La información mostrada contiene errores"
        case .offensiveLanguage:
            return "El contenido incluye lenguaje inapropiado"
        }
    }
    
    var systemImage: String {
        switch self {
        case .newsRepeated:
            return "doc.on.doc"
        case .notRelatedNews:
            return "questionmark.circle"
        case .wrongInformation:
            return "exclamationmark.triangle"
        case .offensiveLanguage:
            return "hand.raised"
        }
    }
    
    var color: Color {
        switch self {
        case .newsRepeated:
            return .orange
        case .notRelatedNews:
            return .blue
        case .wrongInformation:
            return .red
        case .offensiveLanguage:
            return .purple
        }
    }
}
