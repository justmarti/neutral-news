//
//  ProblemSelectionComponents.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct ProblemCard: View {
    let problem: Problem
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? ReportConstants.Spacing.compactButtonSpacing : ReportConstants.Spacing.regularButtonSpacing) {
                Image(systemName: problem.systemImage)
                    .font(isCompact ? .title3 : .title2)
                    .foregroundStyle(isSelected ? .white : problem.color)
                    .frame(
                        width: isCompact ? ReportConstants.Button.compactIconFrameSize : ReportConstants.Button.iconFrameSize,
                        height: isCompact ? ReportConstants.Button.compactIconFrameSize : ReportConstants.Button.iconFrameSize
                    )
                
                VStack(alignment: .leading, spacing: isCompact ? ReportConstants.Spacing.compactTextSpacing : ReportConstants.Spacing.regularTextSpacing) {
                    Text(problem.title)
                        .font(isCompact ? .subheadline : .headline)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    if !isCompact {
                        Text(problem.description)
                            .font(.subheadline)
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(isCompact ? .title3 : .title2)
                    .foregroundStyle(.white)
                    .opacity(isSelected ? 1.0 : 0.0)
            }
            .padding(ReportConstants.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ReportConstants.Layout.cardCornerRadius)
                    .fill(isSelected ? problem.color : problem.color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .animation(.default, value: isSelected)
    }
}

struct CircularProblemButton: View {
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
                    .frame(width: ReportConstants.Button.circularTextWidth)
            }
        }
        .buttonStyle(.plain)
        .animation(.default, value: isSelected)
    }
}

struct ProblemSelectionView: View {
    let isVeryCompact: Bool
    @Bindable var viewModel: ReportProblemViewModel
    
    var body: some View {
        if isVeryCompact {
            compactLayout
        } else {
            regularLayout
        }
    }
    
    private var compactLayout: some View {
        HStack(spacing: ReportConstants.Layout.itemSpacing) {
            ForEach(Problem.allCases, id: \.self) { problem in
                CircularProblemButton(
                    problem: problem,
                    isSelected: viewModel.selectedProblem == problem
                ) {
                    viewModel.selectProblem(problem)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
    
    private var regularLayout: some View {
        VStack(spacing: ReportConstants.Layout.cardSpacing) {
            ForEach(Problem.allCases, id: \.self) { problem in
                ProblemCard(
                    problem: problem,
                    isSelected: viewModel.selectedProblem == problem,
                    isCompact: false
                ) {
                    viewModel.selectProblem(problem)
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
}
