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
    
    /// Calculates the contrast ratio between two colors using WCAG formula
    fileprivate func contrastRatio(with otherColor: Color) -> CGFloat {
        let luminance1 = self.relativeLuminance()
        let luminance2 = otherColor.relativeLuminance()
        
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Calculates the relative luminance of the color
    fileprivate func relativeLuminance() -> CGFloat {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Apply gamma correction
        let sRGBToLinear = { (component: CGFloat) -> CGFloat in
            if component <= 0.03928 {
                return component / 12.92
            } else {
                return pow((component + 0.055) / 1.055, 2.4)
            }
        }
        
        let linearR = sRGBToLinear(red)
        let linearG = sRGBToLinear(green)
        let linearB = sRGBToLinear(blue)
        
        return 0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB
    }
    
    /// Returns a View with adaptive background color based on current color scheme
    /// Dynamically adjusts brightness to maximize contrast with text
    var adaptiveBackground: some View {
        AdaptiveBackgroundView(baseColor: self)
    }
}

struct AdaptiveBackgroundView: View {
    let baseColor: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let targetTextColor: Color = colorScheme == .light ? .black : .white
        let adaptedColor = optimizeContrastDynamically(for: targetTextColor)
        
        return adaptedColor
    }
    
    private func optimizeContrastDynamically(for textColor: Color) -> Color {
        let currentLuminance = baseColor.relativeLuminance()
        let textLuminance = textColor.relativeLuminance()
        let targetContrast: CGFloat = 4.5
        let currentContrast = baseColor.contrastRatio(with: textColor)
        
        if currentContrast >= targetContrast {
            if textLuminance < 0.5 {
                let minLightModeTarget: CGFloat = 0.5
                if currentLuminance >= minLightModeTarget {
                    return baseColor
                }
            } else {
                let maxDarkModeTarget: CGFloat = 0.3
                if currentLuminance <= maxDarkModeTarget {
                    return baseColor
                }
            }
        }
        
        let targetLuminance: CGFloat
        if textLuminance < 0.5 {
            targetLuminance = max(0.6, min(1, (textLuminance + 0.05) * targetContrast - 0.05))
        } else {
            targetLuminance = max(0, min(1, (textLuminance + 0.05) / targetContrast - 0.05))
        }
        
        let uiColor = UIColor(baseColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let adjustmentFactor = sqrt(targetLuminance / currentLuminance)
        
        return Color(
            red: min(1.0, max(0.0, red * adjustmentFactor)),
            green: min(1.0, max(0.0, green * adjustmentFactor)),
            blue: min(1.0, max(0.0, blue * adjustmentFactor))
        )
    }
}
