//
//  ReportConstants.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import Foundation

enum ReportConstants {
    // MARK: - Layout
    enum Layout {
        static let compactHeightThreshold: CGFloat = 300
        static let horizontalPadding: CGFloat = 24
        static let compactTopPadding: CGFloat = 32
        static let itemSpacing: CGFloat = 24
        static let cardSpacing: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let cardCornerRadius: CGFloat = 16
    }
    
    // MARK: - Button Dimensions
    enum Button {
        static let submitHeight: CGFloat = 52
        static let progressScaleEffect: CGFloat = 0.8
        static let circularSize: CGFloat = 60
        static let circularTextWidth: CGFloat = 70
        static let iconFrameSize: CGFloat = 24
        static let compactIconFrameSize: CGFloat = 20
    }
    
    // MARK: - Animations
    enum Animation {
        static let geometryChangeDuration: Double = 0.3
        static let springDuration: Double = 0.6
        static let springBounce: Double = 0.3
        static let iconSize: CGFloat = 64
    }
    
    // MARK: - Timing
    enum Timing {
        static let cooldownPeriod: TimeInterval = 60
        static let autoDismissDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let compactButtonSpacing: CGFloat = 12
        static let regularButtonSpacing: CGFloat = 16
        static let compactTextSpacing: CGFloat = 2
        static let regularTextSpacing: CGFloat = 4
        static let circularButtonSpacing: CGFloat = 8
        static let statusViewSpacing: CGFloat = 32
        static let statusContentSpacing: CGFloat = 24
    }
}