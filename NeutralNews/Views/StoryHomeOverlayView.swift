//
//  StoryHomeOverlayView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/28/26.
//

import SwiftUI

@MainActor
struct StoryHomeOverlayView: View {
    let currentNews: NeutralNews?
    let currentRelatedNews: [News]
    let currentRegion: ContentRegion?
    let onClose: () -> Void

    @State private var isShowingReportProblemSheet = false
    @State private var saveFeedbackTrigger = 0

    var body: some View {
        overlayControls
        .padding(.top)
        .sensoryFeedback(.success, trigger: saveFeedbackTrigger)
        .sheet(isPresented: $isShowingReportProblemSheet) {
            if let currentNews {
                ReportProblemView(news: currentNews)
                    .presentationDetents([.height(200)])
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var overlayControls: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                controlsContent
            }
        } else {
            controlsContent
        }
    }

    private var controlsContent: some View {
        HStack {
            if let currentNews {
                Menu {
                    NeutralNewsOptionsActions(
                        news: currentNews,
                        relatedNews: currentRelatedNews,
                        region: currentRegion,
                        isShowingReportProblemSheet: $isShowingReportProblemSheet,
                        saveFeedbackTrigger: $saveFeedbackTrigger
                    )
                } label: {
                    overlayCircleLabel(systemImage: "ellipsis")
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: onClose) {
                overlayCircleLabel(systemImage: "xmark")
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func overlayCircleLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .modifier(StoryOverlayChromeModifier())
    }

}

private struct StoryOverlayChromeModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background {
                    Circle()
                        .fill(.regularMaterial)
                }
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 1)
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.gray.opacity(0.85), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack {
            StoryHomeOverlayView(
                currentNews: .mock,
                currentRelatedNews: [],
                currentRegion: nil,
                onClose: {}
            )
            .padding(.horizontal)

            Spacer()
        }
    }
}
