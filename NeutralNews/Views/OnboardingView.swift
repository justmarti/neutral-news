//
//  OnboardingView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/07/25.
//

import SwiftUI

// MARK: - Models

struct OnboardingPageData {
    let title: String
    let subtitle: String
    let image: ImageResource?
    let customContent: (() -> AnyView)?

    init(title: String, subtitle: String, image: ImageResource? = nil, customContent: (() -> AnyView)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.customContent = customContent
    }
}

// MARK: - Reusable Components

struct ChatBubble: View {
    let text: String
    let alignment: Alignment
    let maxWidth: CGFloat

    init(_ text: String, alignment: Alignment = .leading, maxWidth: CGFloat = 280) {
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
    private let chatMessages = [
        ("El Madrid vence con facilidad a un Barça en horas bajas", Alignment.leading),
        ("El Gobierno elude su responsabilidad en la crisis económica", Alignment.trailing),
        ("España lidera Europa en crecimiento pese a las críticas de la oposición", Alignment.leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingPageHeader(
                title: "Informarse no es fácil",
                subtitle: "A menudo los medios muestran los hechos de forma parcial"
            )

            VStack(spacing: 16) {
                ForEach(Array(chatMessages.enumerated()), id: \.offset) { _, message in
                    ChatBubble(message.0, alignment: message.1)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

struct OnboardingPageTwo: View {
    var body: some View {
        VStack(alignment: .leading) {
            OnboardingPageHeader(
                title: "Forma tu propia opinión",
                subtitle: "Facts muestra la actualidad sin sesgos ideológicos"
            )

            Image(.screenshot1)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
}

struct OnboardingPageThree: View {
    var body: some View {
        VStack(alignment: .leading) {
            OnboardingPageHeader(
                title: "Resumen neutral",
                subtitle: "Un vistazo claro y objetivo de las noticias"
            )

            Image(.screenshot2)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
        .padding(.bottom, 64)
    }
}

struct OnboardingPageFour: View {
    var body: some View {
        VStack(alignment: .leading) {
            OnboardingPageHeader(
                title: "Compara perspectivas",
                subtitle: "Diferentes versiones de los mismos hechos"
            )

            Image(.screenshot3)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
    }
}

struct OnboardingPageHeader: View {
    let title: String
    let subtitle: String

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
    let onComplete: () -> Void

    private enum Constants {
        static let totalPages = 4
        static let iconSize: CGFloat = 80
        static let animationDuration: TimeInterval = 0.3
        static let buttonVerticalPadding: CGFloat = 8
    }

    private var isLastPage: Bool {
        currentPage >= Constants.totalPages
    }

    private var buttonTitle: String {
        isLastPage ? "Empezar" : "Siguiente"
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
                OnboardingPageTwo().tag(2)
                OnboardingPageThree().tag(3)
                OnboardingPageFour().tag(4)
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
    OnboardingView(isPresented: .constant(true)) {
        print("Onboarding completed")
    }
}
