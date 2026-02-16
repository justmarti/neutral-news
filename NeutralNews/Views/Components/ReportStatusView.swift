//
//  ReportStatusView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct ReportStatusView: View {
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
            
            // Auto dismiss after delay
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
    
    // MARK: - Computed Properties
    
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

#Preview("Success") {
    ReportStatusView(type: .success)
}

#Preview("Error") {
    ReportStatusView(type: .error(.networkError))
}
