//
//  AccentGradientBackground.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 23/9/25.
//

import SwiftUI

struct AccentGradientBackground: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .background {
                Color("nn-background")
                    .ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor.opacity(isEnabled ? 0.5 : 0.0),
                        Color.clear
                    ]),
                    center: .top,
                    startRadius: -300,
                    endRadius: 500
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: isEnabled)
            }
    }
}