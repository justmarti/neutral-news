//
//  OnboardingView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/07/25.
//

import SwiftUI

// MARK: - Models

struct OnboardingPageData {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let image: ImageResource?
    let customContent: (() -> AnyView)?

    init(title: LocalizedStringResource, subtitle: LocalizedStringResource, image: ImageResource? = nil, customContent: (() -> AnyView)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.customContent = customContent
    }
}

// MARK: - Reusable Components

struct ChatBubble: View {
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

// MARK: - Individual Page Views

struct OnboardingPageOne: View {
    private let chatMessages: [(LocalizedStringResource, Alignment)] = [
        ("Lakers cruise past Celtics in dominant home win", Alignment.leading),
        ("White House deflects blame for higher prices", Alignment.trailing),
        ("U.S. growth holds firm despite mounting recession concerns", Alignment.leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingPageHeader(
                title: "Media Noise",
                subtitle: "Between bias and opinion, it’s hard to see what matters"
            )

            VStack(spacing: 16) {
                ForEach(Array(chatMessages.enumerated()), id: \.offset) { _, message in
                    ChatBubble(message.0, alignment: message.1)
                }
            }
            .padding(.top)

            Spacer()
        }
        .padding(.horizontal)
    }
}

struct OnboardingPageTwo: View {
    let image: ImageResource

    var body: some View {
        VStack(alignment: .leading) {
            OnboardingPageHeader(
                title: "Neutral Summary",
                subtitle: "Key facts, clear and straight to the point"
            )

            Image(image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
        .padding(.bottom, 64)
    }
}

struct OnboardingPageThree: View {
    let image: ImageResource

    var body: some View {
        VStack(alignment: .leading) {
            OnboardingPageHeader(
                title: "Multiple Perspectives",
                subtitle: "Different angles on the same story"
            )

            Image(image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 16)
        }
        .padding(.horizontal)
        .padding(.bottom, 48)
    }
}

struct OnboardingPageHeader: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Main View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 1
    @Environment(\.locale) private var appLocale
    let onComplete: () -> Void

    private enum Constants {
        static let totalPages = 3
        static let iconSize: CGFloat = 80
        static let animationDuration: TimeInterval = 0.3
        static let buttonVerticalPadding: CGFloat = 8
    }

    private var isLastPage: Bool {
        currentPage >= Constants.totalPages
    }

    private var buttonTitle: LocalizedStringResource {
        isLastPage ? "Get Started" : "Next"
    }

    private var isSpanishLocale: Bool {
        appLocale.language.languageCode?.identifier == "es"
    }

    private var imageOne: ImageResource {
        isSpanishLocale ? .onboarding01EsES : .onboarding01EnUS
    }

    private var imageTwo: ImageResource {
        isSpanishLocale ? .onboarding02EsES : .onboarding02EnUS
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 0) {
                Image(.icon)
                    .resizable()
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .scaledToFit()
                
                Text("Facts")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundStyle(.secondary)
                    
            }
            
            TabView(selection: $currentPage) {
                OnboardingPageOne().tag(1)
                OnboardingPageTwo(image: imageOne).tag(2)
                OnboardingPageThree(image: imageTwo).tag(3)
            }

            Button(action: handleButtonTap) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.buttonVerticalPadding)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .background(Color.nnBackground.ignoresSafeArea())
        .tabViewStyle(.page)
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .interactiveDismissDisabled()
    }

    // MARK: - Private Methods

    private func handleButtonTap() {
        if isLastPage {
            isPresented = false
            onComplete()
        } else {
            withAnimation(.easeInOut(duration: Constants.animationDuration)) {
                currentPage += 1
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true)) { }
}
