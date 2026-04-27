//
//  AppFeedbackOverlay.swift
//  NeutralNews
//

import SwiftUI

struct AppFeedbackOverlay: View {
    enum Placement {
        case top
        case bottom
    }

    var placement: Placement = .bottom
    var edgePadding: CGFloat = 22

    @State private var feedbackCenter = AppFeedbackCenter.shared
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        ZStack(alignment: alignment) {
            if let feedback = feedbackCenter.currentFeedback {
                AppFeedbackBanner(feedback: feedback)
                    .padding(.horizontal)
                    .padding(edge, edgePadding)
                    .transition(feedbackTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: accessibilityReduceMotion ? 0.01 : 0.2), value: feedbackCenter.currentFeedback != nil)
        .sensoryFeedback(trigger: feedbackCenter.hapticEvent) { _, newValue in
            newValue?.haptic.sensoryFeedback
        }
    }

    private var alignment: Alignment {
        switch placement {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    private var edge: Edge.Set {
        switch placement {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    private var feedbackTransition: AnyTransition {
        if accessibilityReduceMotion {
            .opacity
        } else {
            .move(edge: transitionEdge).combined(with: .opacity)
        }
    }

    private var transitionEdge: Edge {
        switch placement {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        AppFeedbackOverlay()
    }
}
