//
//  MediaHeadlineView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 1/4/25.
//

import SwiftUI

struct MediaHeadlineView: View {
    let news: News
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(news.sourceMedium.pressMedia.name)
                .font(.title2)
                .fontWidth(.expanded)
                .foregroundStyle(.secondary)
            
            Text(news.title)
                .font(.system(size: 18, design: .serif))
                .fontWeight(.semibold)
            
            Spacer()
            
            BiasScoreView(biasScore: news.neutralScore)
        }
        .padding()  
        .frame(width: 230, height: 230)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 24))
    }
}

#Preview {
    MediaHeadlineView(news: .mock)
}
