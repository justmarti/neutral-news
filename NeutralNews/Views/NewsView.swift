//
//  NewsView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 1/7/25.
//

import SwiftUI

struct NewsView: View {
    let news: News
    let relatedNews: [News]
    var namespace: Namespace.ID
    @Environment(\.isBackgroundColorEnabled) private var isBackgroundColorEnabled

    @State private var showSafari = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(news.sourceMedium.pressMedia.name)
                            .font(.title)
                            .fontWidth(.expanded)
                            .foregroundStyle(.secondary)
                        
                        Text(news.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .fontDesign(.serif)
//                            .lineHeight(.tight)
                        
                        CachedAsyncImage(url: URL(string: news.imageUrl ?? "")) { phase in
                            switch phase {
                            case .empty:
                                ShimmerView()
                                    .frame(height: 250)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                EmptyView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: 16))
                        
                        Text(news.description)
//                            .fontDesign(.serif)
                        
                        if let link = URL(string: news.link) {
                            Button {
                                showSafari = true
                            } label: {
                                HStack {
                                    Text("Leer en la fuente")
                                    Image(systemName: "arrow.up.right")
                                }
                                .fontWeight(.semibold)
                            }
                            .safariSheet(url: link, isPresented: $showSafari)
                        }
                        
                        Spacer()
                        
                        Text("Facts es independiente, no está asociado a \(news.sourceMedium.pressMedia.name) ni a ningún otro medio de comunicación.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(minHeight: geometry.size.height)
                }
            }
            .dominantColorBackground(from: news.imageUrl, isEnabled: isBackgroundColorEnabled)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }
    
}

#Preview {
    let namespace = Namespace().wrappedValue
    return NewsView(news: .mock, relatedNews: [.mock, .mock, .mock], namespace: namespace)
        .environment(\.isBackgroundColorEnabled, true)
}
