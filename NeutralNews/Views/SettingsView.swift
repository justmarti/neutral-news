//
//  SettingsView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 6/2/26.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var vm: NewsListViewModel
    
    @AppStorage("isBackgroundColorEnabled") private var isBackgroundColorEnabled = true
    @AppStorage(AppColorScheme.storageKey) private var appColorScheme = AppColorScheme.system.rawValue
    @AppStorage(ContentRegionPreference.storageKey) private var regionPreference = ContentRegionPreference.automatic.rawValue
    
    @State private var showingSafari = false
    @State private var safariURL: URL?
    @State private var showingPaywall = false

    @Environment(\.dismiss) private var dismiss
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
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
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

            if premiumManager.isPremium {
                Section {
                    LabeledContent {
                        Text(subscriptionStatusValue)
                    } label: {
                        Text(subscriptionStatusLabel)
                    }
                } header: {
                    Text("Facts Pro")
                }
            }

            Section("Content") {
                Button {
                    vm.toggleSavedNewsMode()
                    dismiss()
                } label: {
                    SettingsRowLabel(
                        title: "Saved News",
                        systemImage: "bookmark.fill",
                        tint: .pink
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
                        tint: .brown
                    )
                }
                .pickerStyle(.navigationLink)
                .onChange(of: regionPreference) { _, _ in
                    Task {
                        await vm.reloadAfterRegionChange()
                    }
                }

//                SettingsRowLabel(
//                    title: "Notificaciones",
//                    systemImage: "bell.fill",
//                    tint: .red
//                )
//                .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Toggle(isOn: $isBackgroundColorEnabled) {
                    SettingsRowLabel(
                        title: "Colored Background",
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
                        title: "Recommend to a Friend",
                        systemImage: "square.and.arrow.up.fill",
                        tint: .green
                    )
                }
                .buttonStyle(.plain)
            }

            Section("Support") {
                Button {
                    contactSupport()
                } label: {
                    SettingsRowLabel(
                        title: "Contact Us",
                        systemImage: "envelope.fill",
                        tint: .blue
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

            VStack {
                if let appVersionText {
                    Text(appVersionText)
                        .fontDesign(.monospaced)
                }
//                Text("Built by Martí Espinosa in Barcelona")
            }
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
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: 32, height: 32)
                    Image(systemName: systemImage)
                        .font(.headline)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private func openAppStoreReview() {
        guard let url = URL(string: "https://apps.apple.com/app/id6748583935?action=write-review") else { return }
        openURL(url)
    }

    private func contactSupport() {
        guard let url = URL(string: "mailto:support@getfacts.app") else { return }
        openURL(url)
    }

    private var appVersionText: LocalizedStringResource? {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty else {
            return nil
        }

        return "Version \(version)"
    }

    private var subscriptionStatusLabel: LocalizedStringResource {
        if premiumManager.subscriptionExpirationDate == nil {
            return "Access"
        }

        return premiumManager.subscriptionWillRenew == true ? "Renews in" : "Expires in"
    }

    private var subscriptionStatusValue: String {
        guard let expirationDate = premiumManager.subscriptionExpirationDate else {
            return "Lifetime"
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.year, .month, .weekOfMonth, .day]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1

        return formatter.string(from: Date(), to: expirationDate) ?? ""
    }

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
        settingsTransitionNamespace: Namespace().wrappedValue
    )
}
