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
    var namespace: Namespace.ID
    @Environment(\.isBackgroundColorEnabled) private var isBackgroundColorEnabled

    @State private var isShowingReportProblemSheet = false
    
    var body: some View {
        GeometryReader { geometry in
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
                                            
                                            Text("Image from \(news.imageMedium). Source articles are at the bottom of the page.")
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
                        }
                        .padding()
                        
                        Spacer()
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(relatedNews) { new in
                                    NavigationLink {
                                        NewsView(news: new, relatedNews: relatedNews, namespace: namespace)
                                            .environment(\.isBackgroundColorEnabled, isBackgroundColorEnabled)
                                            .navigationTransition(.zoom(sourceID: new.id, in: namespace))
                                    } label: {
                                        MediaHeadlineView(news: new)
                                            .matchedTransitionSource(id: new.id, in: namespace)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .sheet(isPresented: $isShowingReportProblemSheet) {
                ReportProblemView(news: news)
                    .presentationDetents([.height(200), .large])
            }
            .dominantColorBackground(from: news.imageUrl, isEnabled: isBackgroundColorEnabled)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NeutralNewsOptionsMenu(
                        news: news,
                        isShowingReportProblemSheet: $isShowingReportProblemSheet
                    )
                }
            }
        }
    }
}

#Preview {
    let namespace = Namespace().wrappedValue
    return NeutralNewsView(news: .mock, relatedNews: [.mock, .mock, .mock], namespace: namespace)
        .environment(\.isBackgroundColorEnabled, true)
}
