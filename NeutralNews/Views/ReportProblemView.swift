//
//  ReportProblemView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct ReportProblemView: View {
    @State private var viewModel: ReportProblemViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(news: NeutralNews) {
        self._viewModel = State(initialValue: ReportProblemViewModel(news: news))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.showMainContent {
                    mainContent
                } else {
                    Color.clear
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.showMainContent {
                    submitButton
                        .padding(.horizontal, ReportConstants.Layout.horizontalPadding)
                }
            }
        }
        .onChange(of: viewModel.isSubmitted) { _, isSubmitted in
            guard isSubmitted else { return }
            finishWithFeedback(
                "Report sent successfully",
                systemImage: "checkmark.circle",
                style: .success
            )
        }
        .onChange(of: viewModel.reportError) { _, reportError in
            guard let reportError else { return }
            finishWithFeedback(
                reportError.description,
                systemImage: reportError.systemImage,
                style: reportError == .alreadyReported ? .info : .error,
                haptic: reportError.feedbackHaptic
            )
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: ReportConstants.Layout.itemSpacing) {
                ProblemSelectionView(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ReportConstants.Layout.horizontalPadding)
            .padding(.top, ReportConstants.Layout.topPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .transition(.asymmetric(
            insertion: .identity,
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button {
            Task {
                await viewModel.submitReport()
            }
        } label: {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView()
                        .scaleEffect(ReportConstants.Button.progressScaleEffect)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane")
                }
                Text(viewModel.isSubmitting ? "Sending..." : "Send report")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ReportConstants.Button.submitHeight)
            .background(
                Capsule()
                    .fill(viewModel.selectedProblem?.color ?? Color.secondary)
            )
        }
        .disabled(viewModel.selectedProblem == nil || viewModel.isSubmitting)
        .animation(.default, value: viewModel.selectedProblem != nil)
        .animation(.default, value: viewModel.isSubmitting)
    }

    private func finishWithFeedback(
        _ title: LocalizedStringResource,
        systemImage: String,
        style: AppFeedbackCenter.FeedbackStyle,
        haptic: AppFeedbackCenter.FeedbackHaptic? = nil
    ) {
        dismiss()

        Task {
            try? await Task.sleep(for: .milliseconds(220))
            AppFeedbackCenter.shared.show(title, systemImage: systemImage, style: style, haptic: haptic)
        }
    }
}

private extension ReportError {
    var feedbackHaptic: AppFeedbackCenter.FeedbackHaptic {
        switch self {
        case .alreadyReported, .cooldown:
            return .warning
        case .networkError, .firebaseError, .permissionDenied, .unknown:
            return .error
        }
    }
}

#Preview {
    ReportProblemView(news: .mock)
}

private struct ProblemOptionButton: View {
    let problem: Problem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: ReportConstants.Spacing.circularButtonSpacing) {
                ZStack {
                    Circle()
                        .fill(isSelected ? problem.color : problem.color.opacity(0.1))
                        .frame(width: ReportConstants.Button.circularSize, height: ReportConstants.Button.circularSize)
                    
                    Image(systemName: problem.systemImage)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : problem.color)
                }
                
                Text(problem.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? problem.color : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .animation(.default, value: isSelected)
    }
}

private struct ProblemSelectionView: View {
    @Bindable var viewModel: ReportProblemViewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: ReportConstants.Layout.itemSpacing) {
            ForEach(Problem.allCases, id: \.self) { problem in
                ProblemOptionButton(
                    problem: problem,
                    isSelected: viewModel.selectedProblem == problem
                ) {
                    viewModel.selectProblem(problem)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(viewModel.selectedProblem == problem ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
}
