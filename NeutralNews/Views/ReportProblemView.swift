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
        GeometryReader { geometry in
            let isVeryCompact = geometry.size.height < ReportConstants.Layout.compactHeightThreshold
            
            NavigationStack {
                Group {
                    if viewModel.showMainContent {
                        mainContent(isVeryCompact: isVeryCompact)
                    } else if viewModel.isSubmitted {
                        ReportStatusView(type: .success)
                    } else if let error = viewModel.reportError {
                        ReportStatusView(type: .error(error))
                    }
                }
                .navigationTitle(navigationTitle(isVeryCompact: isVeryCompact))
                .navigationBarTitleDisplayMode(.large)
                .safeAreaInset(edge: .bottom) {
                    if viewModel.showMainContent {
                        submitButton
                            .padding(.horizontal, ReportConstants.Layout.horizontalPadding)
                    }
                }
            }
        }
    }
    
    // MARK: - Main Content
    
    private func mainContent(isVeryCompact: Bool) -> some View {
        ScrollView {
            VStack(alignment: isVeryCompact ? .center : .leading, spacing: ReportConstants.Layout.itemSpacing) {
                if !isVeryCompact {
                    headerSection
                }
                ProblemSelectionView(isVeryCompact: isVeryCompact, viewModel: viewModel)
            }
            .padding(.horizontal, ReportConstants.Layout.horizontalPadding)
            .padding(.top, isVeryCompact ? ReportConstants.Layout.compactTopPadding : 0)
            .animation(.easeInOut(duration: ReportConstants.Animation.geometryChangeDuration), value: isVeryCompact)
        }
        .transition(.asymmetric(
            insertion: .identity,
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    private var headerSection: some View {
        Text("Select the type of problem that best describes the issue.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
    
    // MARK: - Helper Methods
    
    private func navigationTitle(isVeryCompact: Bool) -> String {
        if viewModel.isSubmitted {
            return ""
        } else if isVeryCompact {
            return ""
        } else {
            return "Report a problem"
        }
    }
}

#Preview {
    ReportProblemView(news: .mock)
}
