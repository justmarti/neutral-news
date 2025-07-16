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
}