//
//  NeutralNewsOptionsMenu.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

struct NeutralNewsOptionsMenu: View {
    let news: NeutralNews
    @Binding var isBackgroundColorEnabled: Bool
    @Binding var isShowingReportProblemSheet: Bool
    
    var body: some View {
        Menu {
            ShareLink(item: generateShareURL()) {
                Label("Compartir", systemImage: "square.and.arrow.up")
            }
            
            Button {
                withAnimation {
                    isBackgroundColorEnabled.toggle()
                }
            } label: {
                Label("Color de fondo", systemImage: isBackgroundColorEnabled ? "paintbrush.fill" : "paintbrush")
            }
            
            Button {
                isShowingReportProblemSheet.toggle()
            } label: {
                Label("Reportar problema", systemImage: "exclamationmark.bubble")
            }

        } label: {
            Label("Opciones", systemImage: "ellipsis")
        }
    }
    
    private func generateShareURL() -> URL {
        return DeepLinkService.generateShareURL(for: news)
    }
}
