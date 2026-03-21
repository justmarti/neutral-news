//
//  OnboardingView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/07/25.
//

import SwiftUI

// MARK: - Reusable Components

private struct ChatBubble: View {
    let text: LocalizedStringResource
    let alignment: Alignment
    let maxWidth: CGFloat

    init(_ text: LocalizedStringResource, alignment: Alignment = .leading, maxWidth: CGFloat = 280) {
        self.text = text
        self.alignment = alignment
        self.maxWidth = maxWidth
    }

    private var roundedCorners: UnevenRoundedRectangle {
        switch alignment {
        case .leading:
            return UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 24,
                topTrailingRadius: 24
            )
        case .trailing:
            return UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 4,
                topTrailingRadius: 24
            )
        default:
            return UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 24,
                topTrailingRadius: 24
            )
        }
    }

    var body: some View {
        HStack {
            if alignment == .trailing { Spacer() }

            Text(text)
                .font(.title3)
                .fontDesign(.serif)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .clipShape(roundedCorners)
                .frame(maxWidth: maxWidth, alignment: alignment)

            if alignment == .leading { Spacer() }
        }
    }
}

private struct OnboardingPage {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let content: Content

    enum Content {
        case chatPreview([(LocalizedStringResource, Alignment)])
        case image(ImageResource, topPadding: CGFloat)
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    private enum Constants {
        static let horizontalPadding: CGFloat = 24
        static let contentSpacing: CGFloat = 24
        static let bottomPadding: CGFloat = 48
        static let chatTopPadding: CGFloat = 8
        static let chatSpacing: CGFloat = 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.contentSpacing) {
            OnboardingPageHeader(title: page.title, subtitle: page.subtitle)

            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.bottom, Constants.bottomPadding)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page.content {
        case .chatPreview(let chatMessages):
            VStack(spacing: 0) {
                VStack(spacing: Constants.chatSpacing) {
                    ForEach(Array(chatMessages.enumerated()), id: \.offset) { _, message in
                        ChatBubble(message.0, alignment: message.1)
                    }
                }
                .padding(.top, Constants.chatTopPadding)

                Spacer(minLength: 0)
            }
        case .image(let image, let topPadding):
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, topPadding)
                .accessibilityHidden(true)
        }
    }
}

private struct OnboardingPageHeader: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Main View

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0

    private enum Constants {
        static let iconSize: CGFloat = 64
        static let animationDuration: TimeInterval = 0.3
        static let buttonVerticalPadding: CGFloat = 10
        static let horizontalPadding: CGFloat = 24
        static let topPadding: CGFloat = 20
        static let headerBottomPadding: CGFloat = 12
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Media Noise",
            subtitle: "Between bias and opinion, it’s hard to see what matters",
            content: .chatPreview([
                ("Lakers cruise past Celtics in dominant home win", .leading),
                ("White House deflects blame for higher prices", .trailing),
                ("U.S. growth holds firm despite mounting recession concerns", .leading)
            ])
        ),
        OnboardingPage(
            title: "Neutral Summary",
            subtitle: "Key facts, clear and straight to the point",
            content: .image(.onboarding01, topPadding: 0)
        ),
        OnboardingPage(
            title: "Multiple Perspectives",
            subtitle: "Different angles on the same story",
            content: .image(.onboarding02, topPadding: 16)
        )
    ]

    private var brandHeader: some View {
        HStack(spacing: 8) {
            Image(.icon)
                .resizable()
                .scaledToFit()
                .frame(width: Constants.iconSize, height: Constants.iconSize)

            Text("Facts")
                .font(.largeTitle)
                .fontWeight(.black)
                .foregroundStyle(.secondary)
        }
    }

    private var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    private var buttonTitle: LocalizedStringResource {
        isLastPage ? "Get Started" : "Next"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                brandHeader

                Spacer()
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, Constants.topPadding)
            .padding(.bottom, Constants.headerBottomPadding)

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }

            Button(action: handlePrimaryAction) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.buttonVerticalPadding)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.nnBackground.ignoresSafeArea())
        .tabViewStyle(.page)
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .interactiveDismissDisabled()
    }

    // MARK: - Private Methods

    private func handlePrimaryAction() {
        if isLastPage {
            completeOnboarding()
        } else {
            withAnimation(.easeInOut(duration: Constants.animationDuration)) {
                currentPage += 1
            }
        }
    }

    private func completeOnboarding() {
        onComplete()
    }
}

#Preview {
    OnboardingView { }
}
