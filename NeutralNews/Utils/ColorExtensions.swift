//
//  ColorExtensions.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 16/7/25.
//

import SwiftUI

extension Color {
    /// Returns the contrasting text color (black or white) for optimal readability
    var contrastingTextColor: Color {
        // Convert to UIColor for RGB extraction
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate relative luminance using W3C formula
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        // Return white for dark backgrounds, black for light backgrounds
        return luminance > 0.5 ? .black : .white
    }
    
    /// Returns a View with adaptive background color based on current color scheme
    /// Light mode: makes the color lighter, Dark mode: makes the color darker
    var adaptiveBackground: some View {
        AdaptiveBackgroundView(baseColor: self)
    }
}

struct AdaptiveBackgroundView: View {
    let baseColor: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let uiColor = UIColor(baseColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let adaptedColor: Color
        switch colorScheme {
        case .light:
            // Make color lighter by blending with white
            let lightFactor: CGFloat = 0.3
            adaptedColor = Color(
                red: red + (1.0 - red) * lightFactor,
                green: green + (1.0 - green) * lightFactor,
                blue: blue + (1.0 - blue) * lightFactor
            )
        case .dark:
            // Make color darker by reducing brightness
            let darkFactor: CGFloat = 0.6
            adaptedColor = Color(
                red: red * darkFactor,
                green: green * darkFactor,
                blue: blue * darkFactor
            )
        @unknown default:
            adaptedColor = baseColor
        }
        
        return adaptedColor
    }
}