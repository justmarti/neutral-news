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
        if #available(iOS 17.0, *) {
            SubscriptionStoreView(groupID: "21774114") {
                VStack(spacing: 20) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange.gradient)
                        .symbolEffect(.bounce, value: true)
                    
                    VStack(spacing: 8) {
                        Text("Facts Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Desbloquea el acceso completo a la app")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 16) {
                        ProFeatureRow(icon: "newspaper.fill", text: "Resúmenes neutrales ilimitados")
                        ProFeatureRow(icon: "bookmark.fill", text: "Guardar noticias")
                        ProFeatureRow(icon: "arrow.down.circle.fill", text: "Modo offline")
                        ProFeatureRow(icon: "heart.fill", text: "Apoya una app independiente")
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 20)
            }
            .backgroundStyle(.clear)
            .subscriptionStoreButtonLabel(.automatic)
            .subscriptionStorePickerItemBackground(.regularMaterial)
            .subscriptionStoreControlStyle(.pagedProminentPicker)
            .onInAppPurchaseCompletion { product, result in
                if case .success(.success(_)) = result {
                    isPresented = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ahora no") {
                        isPresented = false
                    }
                    .font(.body)
                    .foregroundStyle(.blue)
                }
            }
        } else {
            // Fallback para iOS 16 y anteriores
            StoreView(ids: ["monthly_subscription", "yearly_subscription"])
                .productViewStyle(.compact)
                .onInAppPurchaseCompletion { product, result in
                    if case .success(.success(_)) = result {
                        isPresented = false
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Ahora no") {
                            isPresented = false
                        }
                        .font(.body)
                        .foregroundStyle(.blue)
                    }
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
                .foregroundStyle(.orange)
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
