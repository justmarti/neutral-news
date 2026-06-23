//
//  AppFeedbackCenter.swift
//  NeutralNews
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AppFeedbackCenter {
    enum FeedbackHaptic: Equatable {
        case success
        case warning
        case error

        var sensoryFeedback: SensoryFeedback {
            switch self {
            case .success:
                return .success
            case .warning:
                return .warning
            case .error:
                return .error
            }
        }
    }

    enum FeedbackStyle {
        case loading
        case success
        case info
        case error

        var defaultHaptic: FeedbackHaptic? {
            switch self {
            case .loading:
                return nil
            case .success:
                return .success
            case .info:
                return .warning
            case .error:
                return .error
            }
        }
    }

    struct Feedback: Identifiable {
        let id = UUID()
        let title: LocalizedStringResource
        let systemImage: String?
        let style: FeedbackStyle
    }

    struct HapticEvent: Equatable {
        let id = UUID()
        let haptic: FeedbackHaptic
    }

    static let shared = AppFeedbackCenter()

    private(set) var currentFeedback: Feedback?
    private(set) var hapticEvent: HapticEvent?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(
        _ title: LocalizedStringResource,
        systemImage: String? = nil,
        style: FeedbackStyle = .info,
        haptic: FeedbackHaptic? = nil,
        duration: Duration = .seconds(1.8)
    ) {
        dismissTask?.cancel()
        currentFeedback = Feedback(
            title: title,
            systemImage: systemImage,
            style: style
        )
        if let feedbackHaptic = haptic ?? style.defaultHaptic {
            hapticEvent = HapticEvent(haptic: feedbackHaptic)
        }

        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(for: duration)
                guard !Task.isCancelled else { return }
                self?.dismiss()
            } catch {
                return
            }
        }
    }

    func showLoading(_ title: LocalizedStringResource) {
        dismissTask?.cancel()
        currentFeedback = Feedback(
            title: title,
            systemImage: nil,
            style: .loading
        )
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        currentFeedback = nil
    }
}
