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
        static let horizontalPadding: CGFloat = 24
        static let topPadding: CGFloat = 32
        static let itemSpacing: CGFloat = 12
    }
    
    // MARK: - Button Dimensions
    enum Button {
        static let submitHeight: CGFloat = 52
        static let progressScaleEffect: CGFloat = 0.8
        static let circularSize: CGFloat = 56
    }
    
    // MARK: - Animations
    enum Animation {
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
        static let circularButtonSpacing: CGFloat = 8
        static let statusViewSpacing: CGFloat = 32
        static let statusContentSpacing: CGFloat = 24
    }
}
