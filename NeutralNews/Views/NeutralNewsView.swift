//
//  NeutralNewsView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 13/4/25.
//

import SwiftUI

struct NeutralNewsView: View {
    let news: NeutralNews
    let relatedNews: [News]
    let region: ContentRegion?
    var namespace: Namespace.ID
    let relatedNewsProvider: ((NeutralNews) -> [News])?
    @State private var newsDataManager = NewsDataManager.shared
    @Environment(\.isBackgroundColorEnabled) private var isBackgroundColorEnabled

    @State private var isShowingReportProblemSheet = false
    @State private var isShowingNewsQuestionSheet = false

    private var currentRelatedNews: [News] {
        guard let resolvedRelatedNews = relatedNewsProvider?(news), !resolvedRelatedNews.isEmpty else {
            return relatedNews
        }

        return resolvedRelatedNews
    }

    private var isWaitingForInitialRelatedNews: Bool {
        relatedNewsProvider != nil
            && !news.sourceIds.isEmpty
            && currentRelatedNews.isEmpty
            && newsDataManager.allNews.isEmpty
    }

    init(
        news: NeutralNews,
        relatedNews: [News],
        region: ContentRegion?,
        namespace: Namespace.ID,
        relatedNewsProvider: ((NeutralNews) -> [News])? = nil
    ) {
        self.news = news
        self.relatedNews = relatedNews
        self.region = region
        self.namespace = namespace
        self.relatedNewsProvider = relatedNewsProvider
    }
    
    var body: some View {
        GeometryReader { geometry in
            let resolvedRelatedNews = currentRelatedNews

            ZStack {
                ScrollView {
                    VStack {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(Category.displayName(for: news.category).uppercased())
                                Spacer()
                                Text(news.date.formatted(
                                    Date.FormatStyle.dateTime
                                        .day()
                                        .month()
                                        .hour()
                                        .minute()
                                        .locale(.autoupdatingCurrent)
                                ).uppercased())
                            }
                            .font(.subheadline)
                            .fontWidth(.expanded)
                            .foregroundStyle(.secondary)
                            
                            Text(news.neutralTitle)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .fontDesign(.serif)
                            
                            CachedAsyncImage(url: URL(string: news.imageUrl)) { phase in
                                VStack(alignment: .leading, spacing: 4) {
                                    switch phase {
                                    case .empty:
                                        ShimmerView()
                                            .frame(height: 250)
                                            .clipShape(.rect(cornerRadius: 16))
                                    case .success(let image):
                                        VStack(alignment: .leading) {
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .clipShape(.rect(cornerRadius: 16))
                                            
                                            Text("Image: \(news.imageMedium). Source at the end of the page.")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    case .failure:
                                        EmptyView()
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            Text(news.neutralDescription)
//                                .fontDesign(.serif)

                            NewsQuestionControl(
                                availability: NewsQuestionAvailability.current,
                                hasContext: NewsQuestionContext(
                                    news: news,
                                    relatedNews: resolvedRelatedNews
                                ).hasUsableContent,
                                action: showNewsQuestionSheet
                            )
                            .padding(.top, 8)
                        }
                        .padding()

                        Spacer()

                        if !resolvedRelatedNews.isEmpty || isWaitingForInitialRelatedNews {
                            Text("Media coverage")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .fontWidth(.expanded)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 16)
                                .padding(.top, 32)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    if resolvedRelatedNews.isEmpty {
                                        ForEach(news.sourceIds.prefix(3), id: \.self) { _ in
                                            MediaHeadlineView(news: .mock)
                                                .redacted(reason: .placeholder)
                                                .accessibilityHidden(true)
                                        }
                                    } else {
                                        ForEach(resolvedRelatedNews) { new in
                                            NavigationLink {
                                                NewsView(news: new, relatedNews: resolvedRelatedNews, namespace: namespace)
                                                    .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
                                                    .navigationTransition(.zoom(sourceID: new.id, in: namespace))
                                            } label: {
                                                MediaHeadlineView(news: new)
                                                    .matchedTransitionSource(id: new.id, in: namespace)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .sheet(isPresented: $isShowingReportProblemSheet) {
                ReportProblemView(news: news)
                    .presentationDetents([.height(200)])
            }
            .sheet(isPresented: $isShowingNewsQuestionSheet) {
                NewsQuestionSheet(context: NewsQuestionContext(
                    news: news,
                    relatedNews: currentRelatedNews
                ))
            }
            .dominantColorBackground(from: news.imageUrl, isEnabled: isBackgroundColorEnabled)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NeutralNewsOptionsMenu(
                        news: news,
                        relatedNews: currentRelatedNews,
                        region: region,
                        isShowingReportProblemSheet: $isShowingReportProblemSheet
                    )
                }
            }
        }
    }

    private func showNewsQuestionSheet() {
        isShowingNewsQuestionSheet = true
    }
}

private struct NewsQuestionControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var borderPhase = 0.0

    let availability: NewsQuestionAvailability
    let hasContext: Bool
    let action: () -> Void

    var body: some View {
        switch availability {
        case .available where hasContext:
            Button(action: action) {
                Label("Ask about this story", systemImage: "apple.intelligence")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 4)
                    .modifier(NewsQuestionButtonBackgroundModifier())
                    .background {
                        if !reduceMotion {
                            Capsule()
                                .stroke(animatedBorderGradient, lineWidth: 7)
                                .blur(radius: 7)
                                .opacity(colorScheme == .dark ? 0.52 : 0.28)
                        }
                    }
                    .overlay {
                        Capsule()
                            .stroke(
                                .primary.opacity(colorScheme == .dark ? 0.16 : 0.08),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        if !reduceMotion {
                            Capsule()
                                .stroke(animatedBorderGradient, lineWidth: 1.25)
                                .shadow(
                                    color: .primary.opacity(colorScheme == .dark ? 0.24 : 0.1),
                                    radius: 4
                                )
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityInputLabels(["Ask about this story", "Ask"])
            .onAppear {
                guard !reduceMotion else {
                    return
                }

                withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                    borderPhase = 360
                }
            }
        case .modelNotReady:
            NewsQuestionStatusLabel(
                title: "Apple Intelligence is still getting ready on this device.",
                systemImage: "apple.intelligence"
            )
        case .appleIntelligenceNotEnabled:
            NewsQuestionStatusLabel(
                title: "Turn on Apple Intelligence to ask about this story.",
                systemImage: "apple.intelligence"
            )
        case .available, .deviceNotEligible, .unavailable:
            EmptyView()
        }
    }

    private var animatedBorderGradient: AngularGradient {
        AngularGradient(
            colors: [
                .clear,
                .clear,
                .primary.opacity(colorScheme == .dark ? 0.65 : 0.3),
                .primary.opacity(colorScheme == .dark ? 0.12 : 0.06),
                .clear,
                .clear
            ],
            center: .center,
            startAngle: .degrees(borderPhase),
            endAngle: .degrees(borderPhase + 360)
        )
    }
}

private struct NewsQuestionButtonBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
        }
    }
}

private struct NewsQuestionStatusLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let namespace = Namespace().wrappedValue
    return NeutralNewsView(news: .mock, relatedNews: [.mock, .mock, .mock], region: nil, namespace: namespace)
        .environment(\.isBackgroundColorEnabled, true)
}
