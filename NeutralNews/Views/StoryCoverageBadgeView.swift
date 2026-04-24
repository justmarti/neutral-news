//
//  StoryCoverageBadgeView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 24/4/26.
//

import SwiftUI

struct StoryCoverageBadgeView: View {
    let coverageCount: Int

    private var label: String {
        if coverageCount == 1 {
            return "1 source"
        }

        return "\(coverageCount) sources"
    }

    var body: some View {
        Label(label, systemImage: "square.stack.3d.up")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
    }
}
