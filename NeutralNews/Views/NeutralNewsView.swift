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
    
    @State private var dominantColor: Color = .gray
    @State private var isLoadingImage = false
    @State private var selectedNews: News?
    
    private let imageService = ImageService.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                dominantColor.adaptiveBackground
                    .ignoresSafeArea()
                    .animation(.default, value: dominantColor)
                
                ScrollView {
                    VStack {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(news.category.uppercased())
                                Spacer()
                                Text(news.date.formatted(
                                    Date.FormatStyle.dateTime
                                        .day()
                                        .month(.wide)
                                        .hour()
                                        .minute()
                                        .locale(Locale(identifier: "es_ES"))
                                ).uppercased())
                            }
                            .font(.subheadline)
                            .fontWidth(.expanded)
                            .foregroundStyle(.secondary)
                            
                            Text(news.neutralTitle)
                                .font(.title)
                                .fontWeight(.semibold)
                                .fontDesign(.serif)
                            
                            AsyncImage(url: URL(string: news.imageUrl)) { phase in
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
                                            
                                            // TODO: Si el medio es El Mundo o Expansión, no hay su noticia abajo, arreglar
                                            Text("Imagen extraída de \(Media.from(news.imageMedium)?.pressMedia.name ?? ""), ver su noticia al final de la página.")
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
                                    Button {
                                        selectedNews = new
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
                    .task {
                        await loadDominantColor(from: news.imageUrl)
                    }
                }
                .animation(.default, value: dominantColor)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .sheet(item: $selectedNews) { selectedNews in
                NavigationStack {
                    NewsView(news: selectedNews, relatedNews: relatedNews, namespace: namespace)
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Cerrar") {
                                    self.selectedNews = nil
                                }
                            }
                        }
                }
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: generateShareURL()) {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
    
    private func generateShareURL() -> URL {
        return DeepLinkService.generateShareURL(for: news)
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
    return NeutralNewsView(news: .mock, relatedNews: [.mock, .mock, .mock], namespace: namespace)
}
