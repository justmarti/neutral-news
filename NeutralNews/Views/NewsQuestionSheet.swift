//
//  NewsQuestionSheet.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/7/26.
//

import SwiftUI

struct NewsQuestionSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: NewsQuestionViewModel
    @State private var selectedDetent = PresentationDetent.large
    @State private var responseTask: Task<Void, Never>?
    @FocusState private var isQuestionFieldFocused: Bool

    init(context: NewsQuestionContext) {
        _viewModel = State(initialValue: NewsQuestionViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.messages) { message in
                                NewsQuestionMessageView(message: message)
                                    .id(message.id)
                                    .transition(messageTransition(for: message))
                            }

                            if viewModel.isResponding {
                                NewsQuestionTypingIndicator(reduceMotion: reduceMotion)
                                    .id("typing-indicator")
                                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
                            }

                            if let errorMessage = viewModel.errorMessage {
                                NewsQuestionErrorMessageView(
                                    message: errorMessage,
                                    canRetry: viewModel.canRetry,
                                    retry: retryLastQuestion
                                )
                                    .id("error-message")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("bottom-anchor")
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                        .animation(messageAnimation, value: viewModel.messages.count)
                        .animation(messageAnimation, value: viewModel.isResponding)
                        .animation(messageAnimation, value: shouldShowEmptyState)
                    }
                    .overlay {
                        if shouldShowEmptyState {
                            NewsQuestionEmptyView(hasContext: viewModel.context.hasUsableContent)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom, spacing: 8) {
                        NewsQuestionInputView(
                            draftQuestion: $viewModel.draftQuestion,
                            canSubmit: viewModel.canSubmit,
                            isFocused: $isQuestionFieldFocused,
                            submit: submitQuestion
                        )
                    }
                    .onChange(of: viewModel.messages.count) {
                        scrollToBottom(proxy)
                    }
                    .onChange(of: viewModel.isResponding) {
                        scrollToBottom(proxy)
                    }
                    .onChange(of: viewModel.errorMessage) {
                        scrollToBottom(proxy)
                    }
                }
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onDisappear {
            responseTask?.cancel()
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()

            if reduceMotion {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            } else {
                withAnimation(.smooth(duration: 0.42)) {
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
            }
        }
    }

    private func submitQuestion() {
        withAnimation(messageAnimation) {
            selectedDetent = .large
        }

        responseTask = Task {
            await viewModel.submitQuestion()
        }
    }

    private func retryLastQuestion() {
        responseTask = Task {
            await viewModel.retryLastQuestion()
        }
    }

    private var messageAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : .smooth(duration: 0.42)
    }

    private var shouldShowEmptyState: Bool {
        viewModel.messages.isEmpty && !viewModel.isResponding && viewModel.errorMessage == nil
    }

    private func messageTransition(for message: NewsQuestionMessage) -> AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }

        let anchor: UnitPoint = message.role == .user ? .bottomTrailing : .bottomLeading

        return .move(edge: .bottom)
            .combined(with: .opacity)
            .combined(with: .scale(scale: 0.96, anchor: anchor))
    }
}

private struct NewsQuestionEmptyView: View {
    let hasContext: Bool

    var body: some View {
        if hasContext {
            ContentUnavailableView(
                "Ask about this story",
                systemImage: "apple.intelligence",
                description: Text("Answers use the summary and media coverage on this page.")
            )
        } else {
            ContentUnavailableView(
                "No story context",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Open a story with a summary or loaded sources to ask questions.")
            )
        }
    }
}

private struct NewsQuestionMessageView: View {
    let message: NewsQuestionMessage

    private var isUserMessage: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUserMessage {
                Spacer(minLength: 44)
            }

            VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 0) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isUserMessage ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background {
                        UnevenRoundedRectangle(cornerRadii: bubbleCornerRadii, style: .continuous)
                            .fill(isUserMessage ? Color.accentColor : Color(.secondarySystemBackground))
                    }
                    .overlay {
                        if !isUserMessage {
                            UnevenRoundedRectangle(cornerRadii: bubbleCornerRadii, style: .continuous)
                                .stroke(.quaternary, lineWidth: 0.5)
                        }
                    }
                    .textSelection(.enabled)
                    .accessibilityLabel(messageAccessibilityLabel)

                if hasDetails {
                    NewsQuestionMessageSourcesButton(referencedSources: message.referencedSources)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 320, alignment: isUserMessage ? .trailing : .leading)

            if !isUserMessage {
                Spacer(minLength: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var hasDetails: Bool {
        !message.referencedSources.isEmpty
    }

    private var messageAccessibilityLabel: Text {
        let role = isUserMessage ? String(localized: "You") : String(localized: "Answer")
        return Text(verbatim: "\(role): \(message.text)")
    }

    private var bubbleCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: 22,
            bottomLeading: isUserMessage ? 22 : 8,
            bottomTrailing: isUserMessage ? 8 : 22,
            topTrailing: 22
        )
    }
}

private struct NewsQuestionMessageSourcesButton: View {
    @State private var isShowingSources = false
    let referencedSources: [String]

    var body: some View {
        Button("Sources", systemImage: "newspaper") {
            isShowingSources = true
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .popover(
            isPresented: $isShowingSources,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            NewsQuestionSourcesView(referencedSources: referencedSources)
                .presentationCompactAdaptation(.popover)
        }
        .frame(minHeight: 44, alignment: .topLeading)
        .contentShape(.rect)
        .buttonStyle(.plain)
    }
}

private struct NewsQuestionSourcesView: View {
    let referencedSources: [String]

    var body: some View {
        NewsQuestionTipSection(
            title: "Referenced sources",
            systemImage: "newspaper",
            text: referencedSources.joined(separator: ", ")
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 240, alignment: .leading)
    }
}

private struct NewsQuestionTipSection: View {
    let title: LocalizedStringKey
    let systemImage: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .bold()
                .labelStyle(.titleAndIcon)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

private struct NewsQuestionErrorMessageView: View {
    let message: String
    let canRetry: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if canRetry {
                Button("Try Again", action: retry)
                    .font(.footnote)
                    .bold()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct NewsQuestionTypingIndicator: View {
    let reduceMotion: Bool
    @State private var activeDot = 0

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(dotScale(for: index))
                        .opacity(dotOpacity(for: index))
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Thinking")
            .accessibilityAddTraits(.updatesFrequently)

            Spacer(minLength: 44)
        }
        .frame(maxWidth: .infinity)
        .task {
            guard !reduceMotion else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(360))

                withAnimation(.easeInOut(duration: 0.32)) {
                    activeDot = (activeDot + 1) % 3
                }
            }
        }
    }

    private func dotScale(for index: Int) -> CGFloat {
        guard !reduceMotion else {
            return 1
        }

        return activeDot == index ? 1.25 : 0.82
    }

    private func dotOpacity(for index: Int) -> Double {
        guard !reduceMotion else {
            return 0.65
        }

        return activeDot == index ? 1 : 0.45
    }
}

private struct NewsQuestionInputView: View {
    @Binding var draftQuestion: String
    let canSubmit: Bool
    var isFocused: FocusState<Bool>.Binding
    let submit: () -> Void
    private let controlHeight: CGFloat = 52
    private let sendButtonSize: CGFloat = 36

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TextField("Ask a question", text: $draftQuestion, axis: .vertical)
                .lineLimit(1...4)
                .padding(.leading, 16)
                .padding(.trailing, sendButtonSize + 18)
                .padding(.vertical, 14)
                .focused(isFocused)
                .submitLabel(.send)
                .onSubmit {
                    guard canSubmit else {
                        return
                    }

                    submit()
                }
                .frame(minHeight: controlHeight)
                .background {
                    RoundedRectangle(cornerRadius: controlHeight / 2, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: controlHeight / 2, style: .continuous)
                        .stroke(.quaternary, lineWidth: 0.5)
                }

            Button("Send", systemImage: "arrow.up", action: submit)
                .labelStyle(.iconOnly)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: sendButtonSize, height: sendButtonSize)
                .background {
                    Circle()
                        .fill(canSubmit ? Color.accentColor : Color.secondary.opacity(0.35))
                }
                .disabled(!canSubmit)
                .accessibilityLabel("Send")
                .padding(.trailing, 8)
                .padding(.bottom, 8)
                .animation(.smooth(duration: 0.18), value: canSubmit)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

#Preview {
    NewsQuestionSheet(context: NewsQuestionContext(news: .mock, relatedNews: [.mock]))
}
