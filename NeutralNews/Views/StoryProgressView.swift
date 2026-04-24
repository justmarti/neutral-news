//
//  StoryProgressView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/28/26.
//

import SwiftUI

struct StoryProgressView: View {
    let totalCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCount, id: \.self) { index in
                Capsule()
                    .fill(progressColor(for: index))
                    .frame(maxWidth: .infinity)
                    .frame(height: 4)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .modifier(StoryProgressBackgroundModifier())
    }

    private func progressColor(for index: Int) -> Color {
        if index < currentIndex {
            return .primary.opacity(0.78)
        }

        if index == currentIndex {
            return .primary.opacity(1)
        }

        return .primary.opacity(0.22)
    }
}

private struct StoryProgressBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule())
        } else {
            content
                .background {
                    Capsule()
                        .fill(.regularMaterial)
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.black, .gray.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack {
            StoryProgressView(totalCount: 6, currentIndex: 2)
                .padding()

            Spacer()
        }
    }
}
