//
//  ReportProblemView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct ReportProblemView: View {
    @State private var viewModel: ReportProblemViewModel
    
    init(news: NeutralNews) {
        self._viewModel = State(initialValue: ReportProblemViewModel(news: news))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.showMainContent {
                    mainContent
                } else if viewModel.isSubmitted {
                    ReportStatusView(type: .success)
                } else if let error = viewModel.reportError {
                    ReportStatusView(type: .error(error))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.showMainContent {
                    submitButton
                        .padding(.horizontal, ReportConstants.Layout.horizontalPadding)
                }
            }
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

private struct ReportStatusView: View {
    enum StatusType {
        case success
        case error(ReportError)
    }
    
    let type: StatusType
    @Environment(\.dismiss) private var dismiss
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: ReportConstants.Spacing.statusViewSpacing) {
            Spacer()
            
            VStack(spacing: ReportConstants.Spacing.statusContentSpacing) {
                statusIcon
                statusText
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isVisible = true
            
            Task {
                try? await Task.sleep(nanoseconds: ReportConstants.Timing.autoDismissDelay)
                dismiss()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .identity
        ))
    }
    
    private var statusIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: ReportConstants.Animation.iconSize))
            .foregroundStyle(iconColor, iconSecondaryColor)
            .scaleEffect(isVisible ? 1.0 : 0.5)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.default, value: isVisible)
    }
    
    private var statusText: some View {
        Text(statusMessage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.default, value: isVisible)
    }
    
    private var iconName: String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .error(let reportError):
            return reportError.systemImage
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .success:
            return .white
        case .error:
            return .red
        }
    }
    
    private var iconSecondaryColor: Color {
        switch type {
        case .success:
            return .green
        case .error:
            return .white
        }
    }
    
    private var statusMessage: LocalizedStringResource {
        switch type {
        case .success:
            return "Report sent successfully"
        case .error(let reportError):
            return reportError.description
        }
    }
}
