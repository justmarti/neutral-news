//
//  SettingsView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 6/2/26.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var vm: NewsListViewModel
    @Binding var isPresented: Bool
    
    @AppStorage("isBackgroundColorEnabled") private var isBackgroundColorEnabled = true
    @AppStorage(AppColorScheme.storageKey) private var appColorScheme = AppColorScheme.system.rawValue
    @AppStorage(ContentRegionPreference.storageKey) private var regionPreference = ContentRegionPreference.automatic.rawValue
    
    @State private var showingSafari = false
    @State private var safariURL: URL?
    @State private var showingPaywall = false

    @Environment(\.openURL) private var openURL
    
    private let premiumManager = PremiumManager.shared
    let settingsTransitionNamespace: Namespace.ID

    var body: some View {
        NavigationStack {
            settingsContent
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .safariSheet(url: safariURL, isPresented: $showingSafari)
            .sheet(isPresented: $showingPaywall) {
                PaywallView(isPresented: $showingPaywall)
            }
        }
        .settingsSheetZoomTransition(namespace: settingsTransitionNamespace)
    }

    @ViewBuilder
    private var settingsContent: some View {
        let list = settingsList
        switch selectedColorScheme {
        case .system:
            list
        case .light:
            list.preferredColorScheme(.light)
        case .dark:
            list.preferredColorScheme(.dark)
        }
    }

    private var settingsList: some View {
        List {
            if !premiumManager.isPremium {
                Section {
                    Button {
                        showingPaywall = true
                    } label: {
                        premiumBanner
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            Section("Appearance") {
                Toggle(isOn: $isBackgroundColorEnabled) {
                    SettingsRowLabel(
                        title: "Colored background",
                        systemImage: "paintbrush.fill",
                        tint: .orange
                    )
                }
                .tint(.accentColor)

                Picker(selection: $appColorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.title).tag(scheme.rawValue)
                    }
                } label: {
                    SettingsRowLabel(
                        title: "Theme",
                        systemImage: "circle.lefthalf.filled",
                        tint: .indigo
                    )
                }
                .pickerStyle(.navigationLink)
            }

            Section("Content") {
                Button {
                    withAnimation {
                        vm.toggleSavedNewsMode()
                        isPresented = false
                    }
                } label: {
                    SettingsRowLabel(
                        title: "Saved news",
                        systemImage: "bookmark.fill",
                        tint: .blue
                    )
                }
                .buttonStyle(.plain)

                Picker(selection: $regionPreference) {
                    ForEach(ContentRegionPreference.allCases) { preference in
                        Text(preference.title).tag(preference.rawValue)
                    }
                } label: {
                    SettingsRowLabel(
                        title: "Region",
                        systemImage: "globe.americas.fill",
                        tint: .teal
                    )
                }
                .pickerStyle(.navigationLink)
                .onChange(of: regionPreference) { _, _ in
                    Task {
                        await NewsDataManager.shared.resetForRegionChange()
                        await vm.refreshNews()
                    }
                }

//                SettingsRowLabel(
//                    title: "Notificaciones",
//                    systemImage: "bell.fill",
//                    tint: .red
//                )
//                .foregroundStyle(.secondary)
            }

            Section("Promote") {
                Button {
                    openAppStoreReview()
                } label: {
                    SettingsRowLabel(
                        title: "Rate on the App Store",
                        systemImage: "star.fill",
                        tint: .yellow,
                        showsExternalIndicator: true
                    )
                }
                .buttonStyle(.plain)

                ShareLink(item: URL(string: "https://apps.apple.com/app/id6748583935")!) {
                    SettingsRowLabel(
                        title: "Recommend to a friend",
                        systemImage: "square.and.arrow.up.fill",
                        tint: .green
                    )
                }
                .buttonStyle(.plain)
            }

            Section("Legal") {
                Button {
                    safariURL = URL(string: "https://getfacts.app/privacy")
                    showingSafari = true
                } label: {
                    SettingsRowLabel(
                        title: "Privacy Policy",
                        systemImage: "hand.raised.fill",
                        tint: .gray
                    )
                }
                .buttonStyle(.plain)

                Button {
                    safariURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                    showingSafari = true
                } label: {
                    SettingsRowLabel(
                        title: "Terms of Use",
                        systemImage: "doc.text.fill",
                        tint: .gray
                    )
                }
                .buttonStyle(.plain)
            }

//            if premiumManager.isPremium {
//                premiumThanksBanner
//                    .listRowBackground(Color.clear)
//                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
//                    .listRowSeparator(.hidden)
//            }

            Text("Built by Martí Espinosa in Barcelona")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private var premiumBanner: some View {
        VStack(alignment: .leading, spacing: 32) {
            Image("icon")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            VStack(alignment: .leading) {
                Text("Facts Pro")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Unlock full access.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.6), Color("nn-background")],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 2)
                )
        }
    }

//    private var premiumThanksBanner: some View {
//        VStack(alignment: .center) {
//            Image(systemName: "heart.fill")
//                .font(.title)
//                .symbolEffect(.pulse, options: .repeating.speed(0.5))
//
//            Text("Thanks for supporting Facts")
//                .font(.headline)
//            Text(subscriptionStatusText)
//                .font(.subheadline)
//        }
//        .padding()
//        .padding(.vertical)
//        .foregroundStyle(.secondary)
//        .frame(maxWidth: .infinity)
//    }

    private struct SettingsRowLabel: View {
        let title: LocalizedStringResource
        let systemImage: String
        let tint: Color
        var showsExternalIndicator = false

        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: 28, height: 28)
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(title)
                Spacer()
                if showsExternalIndicator {
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func openAppStoreReview() {
        guard let url = URL(string: "https://apps.apple.com/app/id6748583935?action=write-review") else { return }
        openURL(url)
    }

//    private var subscriptionStatusText: String {
//        guard let expirationDate = premiumManager.subscriptionExpirationDate else {
//            return "Tu suscripción es vitalicia"
//        }
//
//        let now = Date()
//        let dayDifference = Calendar.current.dateComponents([.day], from: now, to: expirationDate).day ?? 0
//        let remainingDays = max(dayDifference, 0)
//        let remainingMonths = max(remainingDays / 30, 0)
//
//        let remainingText: String
//        if remainingDays >= 60 {
//            remainingText = remainingMonths == 1 ? "1 mes" : "\(remainingMonths) meses"
//        } else {
//            remainingText = remainingDays == 1 ? "1 día" : "\(remainingDays) días"
//        }
//
//        if premiumManager.subscriptionWillRenew == true {
//            return "Tu suscripción renueva en \(remainingText)"
//        } else {
//            return "Tu suscripción termina en \(remainingText)"
//        }
//    }

    private var selectedColorScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorScheme) ?? .system
    }

}

private extension View {
    @ViewBuilder
    func settingsSheetZoomTransition(namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: "settings-sheet", in: namespace))
        } else {
            self
        }
    }
}

#Preview {
    SettingsView(
        vm: NewsListViewModel.shared,
        isPresented: .constant(true),
        settingsTransitionNamespace: Namespace().wrappedValue
    )
}
