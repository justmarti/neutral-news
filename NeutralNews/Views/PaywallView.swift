//
//  PaywallView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/07/25.
//

import SwiftUI
import StoreKit
import RevenueCat

struct PaywallView: View {
    @Binding var isPresented: Bool
    @State private var isProcessingPurchase = false

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
        .overlay {
            if isProcessingPurchase {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)

                        Text("Activando suscripción...")
                            .font(.headline)
                    }
                    .padding(32)
                    .background(.regularMaterial, in: .rect(cornerRadius: 16))
                }
            }
        }
        .onInAppPurchaseCompletion { product, result in
            switch result {
            case .success(.success(let transaction)):
                print("✅ Purchase successful: \(product.displayName) - \(transaction.unsafePayloadValue.id)")

                isProcessingPurchase = true

                Task {
                    do {
                        // Sync with RevenueCat and force premium status update
                        let customerInfo = try await Purchases.shared.syncPurchases()
                        print("✅ Purchase synced with RevenueCat")

                        // Force immediate premium status update
                        await PremiumManager.shared.updatePremiumStatus(customerInfo)

                    } catch {
                        print("⚠️ Sync error (transaction still valid): \(error)")
                        // Fallback: check status manually
                        await PremiumManager.shared.checkSubscriptionStatus()
                    }

                    await MainActor.run {
                        isProcessingPurchase = false
                        isPresented = false
                    }
                }
            case .success(.userCancelled):
                print("🚫 Purchase cancelled by user")
            case .success(.pending):
                print("⏳ Purchase pending approval")
            case .failure(let error):
                print("❌ Purchase failed: \(error.localizedDescription)")
            @unknown default:
                print("⚠️ Unknown purchase result")
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
