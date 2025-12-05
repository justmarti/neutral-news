//
//  BiasScoreView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 1/4/25.
//

import SwiftUI

struct BiasScoreView: View {
    var biasScore: Int
    let maxScore = 10
    
    @State private var showInfo: Bool = false
    
    var body: some View {
        HStack {
            Gauge(value: Double(biasScore / 5), in: 0.0...Double(maxScore)) {
                EmptyView()
            }
            .tint(Color.accent.gradient)
            
            Button("Info", systemImage: "info.circle") {
                showInfo.toggle()
            }
            .labelStyle(.iconOnly)
            .popover(isPresented: $showInfo, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                infoPopover
            }
        }
        
//        HStack {
//            Gauge(value: Double(biasScore), in: 0.0...Double(maxScore)) {
//                EmptyView()
//            }
//            .tint(
//                LinearGradient(
//                    gradient: Gradient(colors: [.red, .green]),
//                    startPoint: .leading,
//                    endPoint: .trailing
//                )
//            )
//            
//            Button("Info", systemImage: "info.circle") {
//                showInfo.toggle()
//            }
//            .labelStyle(.iconOnly)
//            .popover(isPresented: $showInfo, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
//                infoPopover
//            }
//        }
//        
//        HStack {
//            Gauge(value: Double(biasScore), in: 0.0...Double(maxScore)) {
//                EmptyView()
//            }
//            .gaugeStyle(.accessoryLinear)
//            .tint(
//                LinearGradient(
//                    gradient: Gradient(colors: [.red, .green]),
//                    startPoint: .leading,
//                    endPoint: .trailing
//                )
//            )
//            
//            Button("Info", systemImage: "info.circle") {
//                showInfo.toggle()
//            }
//            .labelStyle(.iconOnly)
//            .popover(isPresented: $showInfo, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
//                infoPopover
//            }
//        }
    }
    
    private var infoPopover : some View {
        HStack {
            Image(systemName: "\(Int(biasScore/5)).circle")
                .font(.largeTitle)
                .foregroundStyle(.accent, .secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Nivel de neutralidad")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.accent)
                Text("Este valor indica cuán neutral es la noticia,\nsiendo 0 muy sesgada y 10 neutral.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .presentationCompactAdaptation(.popover)
    }
}

#Preview {
    BiasScoreView(biasScore: 40)
        .padding()
}
