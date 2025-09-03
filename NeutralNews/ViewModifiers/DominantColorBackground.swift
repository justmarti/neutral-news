//
//  DominantColorBackground.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct DominantColorBackground: ViewModifier {
    let imageUrl: String?
    let isEnabled: Bool
    
    @State private var dominantColor: Color = .nnBackground
    @State private var isLoading = false
    
    private let imageService = ImageService.shared
    
    func body(content: Content) -> some View {
        content
            .background {
                if isEnabled {
                    dominantColor.adaptiveBackground
                        .ignoresSafeArea()
                        .animation(.default, value: dominantColor)
                } else {
                    Color.nnBackground
                        .ignoresSafeArea()
                }
            }
            .task(id: imageUrl) {
                guard isEnabled else { return }
                await loadDominantColor()
            }
    }
    
    private func loadDominantColor() async {
        isLoading = true
        
        let color = await imageService.getDominantColor(from: imageUrl)
        
        await MainActor.run {
            self.dominantColor = color
            self.isLoading = false
        }
    }
}

extension View {
    func dominantColorBackground(from imageUrl: String?, isEnabled: Bool = true) -> some View {
        modifier(DominantColorBackground(imageUrl: imageUrl, isEnabled: isEnabled))
    }
}
