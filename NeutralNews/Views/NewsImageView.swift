//
//  NewsImageView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI

struct NewsImageView: View {
    let news: NeutralNews
    let imageUrl: String?
    @Environment(\.displayScale) private var displayScale

    // Gradient is created once and shared by all instances
    private static let overlayGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color.black.opacity(0),
            Color.black.opacity(0.2),
            Color.black.opacity(0.8),
            Color.black.opacity(0.9),
            Color.black.opacity(1)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                CachedAsyncImage(
                    url: URL(string: imageUrl ?? ""),
                    maxPixelSize: Double(geometry.size.width * displayScale)
                ) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: 250)
                            .clipped()
                    } else {
                        ShimmerView()
                            .frame(width: geometry.size.width, height: 250)
                    }
                }
                
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .frame(height: 180)
                    .mask(Self.overlayGradient)
                
                Text(news.neutralTitle)
                    .padding(.horizontal, 12)
                    .padding(.vertical)
                    .font(.system(size: 22, design: .serif))
//                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geometry.size.width)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NewsImageView(
        news: NeutralNews.mock,
        imageUrl: "https://www.lavanguardia.com/files/og_thumbnail/files/fp/uploads/2025/04/22/68075b725f598.r_d.1714-2017-0.jpeg"
    )
    .padding()
}
