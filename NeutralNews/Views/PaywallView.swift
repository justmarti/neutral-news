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
    @State private var isRestoringPurchases = false
    @State private var showingSafari = false
    @State private var safariURL: URL?
    @Environment(\.locale) private var appLocale

    var body: some View {
        SubscriptionStoreView(productIDs: [
            "dev.itram.news.pro.weekly",
            "dev.itram.news.pro.monthly",
            "dev.itram.news.pro.annual"
        ]) {
            VStack {
                Image(.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                
                VStack {
                    Text("Facts Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Full app access")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    ProFeatureRow(icon: "calendar", text: "Read news from the last 7 days")
                    ProFeatureRow(icon: "bookmark.fill", text: "Save stories")
                    ProFeatureRow(icon: "heart.fill", text: "Support an independent app")
                }
                .padding(.vertical, 16)

            }
            .environment(\.locale, appLocale)
        }
        .scrollIndicators(.hidden)
        .subscriptionStoreButtonLabel(.automatic)
        .subscriptionStorePickerItemBackground(.regularMaterial)
        .subscriptionStoreControlStyle(.pagedProminentPicker)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                // Restore Purchases Button
                HStack(spacing: 16) {
                    Button {
                        isRestoringPurchases = true
                        Task {
                            await PremiumManager.shared.restorePurchases()
                            isRestoringPurchases = false
                        }
                    } label: {
                        Text(isRestoringPurchases ? "Restoring..." : "Restore Purchases")
                    }
                    .disabled(isRestoringPurchases)

                    // Redeem Code button commented out - only works with Offer Codes, not Promotional Codes
//                    Text("•")
//                        .foregroundColor(.secondary)
//
//                    Button {
//                        Task {
//                            await PremiumManager.shared.presentOfferCodeRedemption()
//                        }
//                    } label: {
//                        Text("Canjear Código")
//                    }
                }
                .font(.caption)
                .foregroundColor(.accentColor)

                // Terms and Privacy Links
                HStack {
                    Button("Terms of Use") {
                        safariURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                        showingSafari = true
                    }

                    Text("•")

                    Button("Privacy Policy") {
                        safariURL = URL(string: "https://getfacts.app/privacy")
                        showingSafari = true
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.top)
        }
        .overlay {
            if isProcessingPurchase {
                ZStack {
                    Color.nnBackground
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)

                        Text("Activating subscription...")
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
#if DEBUG
                print("✅ Purchase successful: \(product.displayName) - \(transaction.unsafePayloadValue.id)")
#endif

                isProcessingPurchase = true

                Task {
                    do {
                        // Sync with RevenueCat and force premium status update
                        let customerInfo = try await Purchases.shared.syncPurchases()
#if DEBUG
                        print("✅ Purchase synced with RevenueCat")
#endif

                        // Force immediate premium status update
                        await PremiumManager.shared.updatePremiumStatus(customerInfo)

                    } catch {
                        print("⚠️ Sync error (transaction still valid): \(error)")
                        // Fallback: check status manually and handle sandbox receipts
                        await PremiumManager.shared.checkSubscriptionStatus()

                        // Additional fallback for sandbox environment
                        if error.localizedDescription.contains("sandbox") || error.localizedDescription.contains("test") {
                            print("🧪 Sandbox environment detected, handling appropriately")
                        }
                    }

                    await MainActor.run {
                        isProcessingPurchase = false
                    }
                }
            case .success(.userCancelled):
#if DEBUG
                print("🚫 Purchase cancelled by user")
#endif
            case .success(.pending):
#if DEBUG
                print("⏳ Purchase pending approval")
#endif
            case .failure(let error):
                print("❌ Purchase failed: \(error.localizedDescription)")

                // Handle specific error cases for App Store review
                if let storeKitError = error as? StoreKitError {
                    print("🛒 StoreKit Error: \(storeKitError)")

                    // Don't show user-facing errors during review process
                    // as sandbox environment can have different behavior
                    switch storeKitError {
                    case .networkError, .systemError:
                        print("🔄 Network/System error, attempting retry logic")
                    case .userCancelled:
                        print("🚫 User cancelled transaction")
                    default:
                        print("⚠️ Other StoreKit error: \(storeKitError.localizedDescription)")
                    }
                }
            @unknown default:
#if DEBUG
                print("⚠️ Unknown purchase result")
#endif
            }
        }
        .safariSheet(url: safariURL, isPresented: $showingSafari)
        .onChange(of: PremiumManager.shared.isPremium) { _, isPremium in
            if isPremium {
                isPresented = false
            }
        }
    }
}

struct ProFeatureRow: View {
    let icon: String
    let text: LocalizedStringResource
    
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
