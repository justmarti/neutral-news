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
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var dominantColor: Color = .nnBackground
    @State private var isLoading = false
    
    private let imageService = ImageService.shared

    private var foregroundColor: Color {
        guard isEnabled, colorScheme == .light else {
            return .primary
        }

        return dominantColor.lightModeDominantForeground
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundStyle(foregroundColor)
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
        guard !Task.isCancelled else { return }

        dominantColor = color
        isLoading = false
    }
}

extension View {
    func dominantColorBackground(from imageUrl: String?, isEnabled: Bool = true) -> some View {
        modifier(DominantColorBackground(imageUrl: imageUrl, isEnabled: isEnabled))
    }
}
