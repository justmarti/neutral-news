//
//  Category.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 1/5/25.
//

import Foundation

enum Category: String, CaseIterable, Decodable, Hashable {
    case economia = "Economía"
    case politica = "Política"
    case ciencia = "Ciencia"
    case tecnologia = "Tecnología"
    case cultura = "Cultura"
    case sociedad = "Sociedad"
    case salud = "Salud"
    case deportes = "Deportes"
    case nacional = "Nacional"
    case internacional = "Internacional"
    case entretenimiento = "Entretenimiento"
    case educacion = "Educación"
    case sucesos = "Sucesos"
    case opinion = "Opinión"
    case medioAmbiente = "Medio Ambiente"
//    case otras = "Otras"
    
    var systemImageName: String {
        switch self {
        case .economia: return "eurosign.circle"
        case .politica: return "building.columns"
        case .ciencia: return "atom"
        case .tecnologia: return "cpu"
        case .cultura: return "book"
        case .sociedad: return "person.2"
        case .salud: return "heart"
        case .deportes: return "sportscourt"
        case .nacional: return "flag"
        case .internacional: return "globe"
        case .entretenimiento: return "popcorn"
        case .educacion: return "graduationcap"
        case .sucesos: return "exclamationmark.triangle"
        case .opinion: return "quote.bubble"
        case .medioAmbiente: return "leaf"
//        case .otras: return "questionmark"
        }
    }
}
