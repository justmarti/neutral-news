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
    
    @State private var dominantColor: Color = .gray
    @State private var isLoadingImage = false
    
    private let imageService = ImageService.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                dominantColor
                    .ignoresSafeArea()
                    .animation(.default, value: dominantColor)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(news.sourceMedium.pressMedia.name)
                            .font(.title)
                            .fontWidth(.expanded)
                            .foregroundStyle(dominantColor.contrastingTextColor.secondary)
                        
                        Text(news.title)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(dominantColor.contrastingTextColor)
//                            .fontDesign(.serif)
                        
                        AsyncImage(url: URL(string: news.imageUrl ?? "")) { phase in
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
                            .foregroundStyle(dominantColor.contrastingTextColor)
//                            .fontDesign(.serif)
                        
                        if let link = URL(string: news.link) {
                            Link("Leer más en la fuente", destination: link)
                                .foregroundStyle(dominantColor.contrastingTextColor)
//                                .fontDesign(.serif)
                        }
                        
                        Spacer()
                        
                        Text("Neutral News es independiente, no está asociado a \(news.sourceMedium.pressMedia.name) ni a ningún otro medio de comunicación.")
                            .font(.caption)
                            .foregroundStyle(dominantColor.contrastingTextColor.secondary)
                    }
                    .padding()
                    .frame(minHeight: geometry.size.height)
                    .task {
                        await loadDominantColor(from: news.imageUrl)
                    }
                }
                .animation(.default, value: dominantColor.contrastingTextColor)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }
    
    private func loadDominantColor(from imageUrl: String?) async {
        isLoadingImage = true
        
        let color = await imageService.getDominantColor(from: imageUrl)
        
        await MainActor.run {
            self.dominantColor = color
            self.isLoadingImage = false
        }
    }
}

#Preview {
    let namespace = Namespace().wrappedValue
    return NewsView(news: .mock, relatedNews: [.mock, .mock, .mock], namespace: namespace)
}
