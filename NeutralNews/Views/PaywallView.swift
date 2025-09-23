//
//  PaywallView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/07/25.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        SubscriptionStoreView(groupID: "21774114") {
            VStack {
                Image(.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                
                VStack {
                    Text("Facts Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Acceso completo a la app")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    ProFeatureRow(icon: "calendar", text: "Lee noticias de los últimos 7 días")
                    ProFeatureRow(icon: "bookmark.fill", text: "Guarda noticias")
                    ProFeatureRow(icon: "heart.fill", text: "Apoya una app independiente")
                }
                .padding(.vertical, 16)
            }
        }
        .scrollIndicators(.hidden)
        .subscriptionStoreButtonLabel(.automatic)
        .subscriptionStorePickerItemBackground(.regularMaterial)
        .subscriptionStoreControlStyle(.pagedProminentPicker)
        .onInAppPurchaseCompletion { product, result in
            if case .success(.success(_)) = result {
                isPresented = false
            }
        }
    }
}

struct ProFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }
}

#Preview {
    PaywallView(isPresented: .constant(true))
}
