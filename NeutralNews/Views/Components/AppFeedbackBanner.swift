//
//  AppFeedbackBanner.swift
//  NeutralNews
//

import SwiftUI

struct AppFeedbackBanner: View {
    let feedback: AppFeedbackCenter.Feedback

    var body: some View {
        HStack(spacing: 12) {
            leadingIndicator

            Text(feedback.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(feedback.title)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        if feedback.style == .loading {
            ProgressView()
        } else if let systemImage = feedback.systemImage {
            Image(systemName: systemImage)
                .font(.headline)
                .symbolVariant(feedback.style == .success ? .fill : .none)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AppFeedbackBanner(
            feedback: .init(
                title: "Opening article",
                systemImage: nil,
                style: .loading
            )
        )
        AppFeedbackBanner(
            feedback: .init(
                title: "Headline copied",
                systemImage: "doc.on.doc",
                style: .success
            )
        )
    }
    .padding()
}
