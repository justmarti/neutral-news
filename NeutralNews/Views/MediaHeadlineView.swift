//
//  MediaHeadlineView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 1/4/25.
//

import SwiftUI

struct MediaHeadlineView: View {
    let news: News

    private var compactPublisherName: String {
        switch news.publisher {
        case "The New York Times":
            return "New York Times"
        case "The Washington Post":
            return "Washington Post"
        case "The Wall Street Journal":
            return "WSJ"
        default:
            return news.publisher
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(compactPublisherName)
                .font(.title2)
                .fontWidth(.expanded)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityLabel(news.publisher)
            
            Text(news.title)
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
        }
        .padding()  
        .frame(width: 220, height: 220, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 24))
    }
}

#Preview {
    MediaHeadlineView(news: .mock)
}
