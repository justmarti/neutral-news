//
//  NewsDetailViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftUI

@Observable
final class NewsDetailViewModel {
    
    // MARK: - Dependencies
    private let imageService = ImageService.shared
    
    // MARK: - UI State
    var dominantColor: Color = .gray
    var isLoadingImage = false
    
    // MARK: - Public Methods
    
    func loadDominantColor(from imageUrl: String?) async {
        await MainActor.run {
            isLoadingImage = true
        }
        
        let color = await imageService.getDominantColor(from: imageUrl)
        
        await MainActor.run {
            self.dominantColor = color
            self.isLoadingImage = false
        }
    }
    
    func resetState() {
        dominantColor = .gray
        isLoadingImage = false
    }
}