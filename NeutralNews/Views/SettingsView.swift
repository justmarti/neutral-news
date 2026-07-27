//
//  SettingsView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 6/2/26.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var vm: NewsListViewModel
    let systemColorScheme: ColorScheme
    let showPaywall: () -> Void
#if DEBUG
    var showDebugOnboarding: () -> Void = {}
#endif
    
    @AppStorage("isBackgroundColorEnabled") private var isBackgroundColorEnabled = true
    @AppStorage(AppColorScheme.storageKey) private var appColorScheme = AppColorScheme.system.rawValue
    @AppStorage(ContentRegionPreference.storageKey) private var regionPreference = ContentRegionPreference.automatic.rawValue
    
    @State private var showingSafari = false
    @State private var safariURL: URL?
    private let pushNotificationService = PushNotificationService.shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    private let premiumManager = PremiumManager.shared

    var body: some View {
        NavigationStack {
            settingsList
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
        }
        .task {
            await pushNotificationService.refreshAuthorizationStatus()
        }
        .preferredColorScheme(isDarkModeForced ? .dark : systemColorScheme)
    }

    private var settingsList: some View {
        @Bindable var bindablePushNotificationService = pushNotificationService
#if DEBUG
        @Bindable var bindablePremiumManager = premiumManager
#endif

        return List {
            if !premiumManager.isPremium {
                Section {
                    Button {
                        showPaywall()
                        dismiss()
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
                        tint: .brown
                    )
                }
                .pickerStyle(.navigationLink)
                .onChange(of: regionPreference) { _, _ in
                    Task {
                        await vm.reloadAfterRegionChange()
                        pushNotificationService.handleRegionPreferenceChange()
                    }
                }
            }

            Section {
                Toggle(isOn: $bindablePushNotificationService.isTopStoriesToggleOn) {
                    SettingsRowLabel(
                        title: "Top Stories",
                        systemImage: "bell.badge.fill",
                        tint: .red
                    )
                }
                .tint(.accentColor)

                if bindablePushNotificationService.authorizationStatus == .denied {
                    Button {
                        openSystemSettings()
                    } label: {
                        SettingsRowLabel(
                            title: "Open Notification Settings",
                            systemImage: "gear",
                            tint: .gray,
                            showsExternalIndicator: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Notifications")
            } footer: {
                if let footerText = bindablePushNotificationService.notificationsFooterText {
                    Text(footerText)
                }
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

                Toggle(isOn: isDarkModeForcedBinding) {
                    SettingsRowLabel(
                        title: "Always Dark Mode",
                        systemImage: "moon.fill",
                        tint: .indigo
                    )
                }
                .tint(.accentColor)
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
//                Button {
//                    Task {
//                        await premiumManager.presentOfferCodeRedemption()
//                        await premiumManager.refreshSubscriptionStatusAfterActivation()
//                    }
//                } label: {
//                    SettingsRowLabel(
//                        title: "Redeem Code",
//                        systemImage: "ticket.fill",
//                        tint: .purple
//                    )
//                }
//                .buttonStyle(.plain)

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

#if DEBUG
            Section("Developer") {
                Toggle(isOn: $bindablePremiumManager.isDebugPremiumEnabled) {
                    SettingsRowLabel(
                        title: "Facts Pro",
                        systemImage: "crown.fill",
                        tint: .orange
                    )
                }
                .tint(.accentColor)

                Button {
                    showPaywall()
                    dismiss()
                } label: {
                    SettingsRowLabel(
                        title: "Show Paywall",
                        systemImage: "creditcard.fill",
                        tint: .teal
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showDebugOnboarding()
                    dismiss()
                } label: {
                    SettingsRowLabel(
                        title: "Show Onboarding",
                        systemImage: "sparkles",
                        tint: .pink
                    )
                }
                .buttonStyle(.plain)
            }
#endif

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
            Image(.icon)
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
        .background(
            LinearGradient(
                colors: [.accent.opacity(0.6), .nnBackground],
                startPoint: .bottomTrailing,
                endPoint: .topLeading
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(.primary.opacity(0.1), lineWidth: 2)
        )
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

    private func openSystemSettings() {
        let settingsURLString = UIApplication.openNotificationSettingsURLString
        let fallbackURLString = UIApplication.openSettingsURLString

        guard let settingsURL = URL(string: settingsURLString.isEmpty ? fallbackURLString : settingsURLString) else {
            return
        }

        openURL(settingsURL)
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
            return String(localized: "Lifetime")
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

    private var isDarkModeForcedBinding: Binding<Bool> {
        Binding(
            get: { selectedColorScheme == .dark },
            set: { isForced in
                appColorScheme = isForced ? AppColorScheme.dark.rawValue : AppColorScheme.system.rawValue
            }
        )
    }

    private var isDarkModeForced: Bool {
        selectedColorScheme == .dark
    }

}

#Preview {
    SettingsView(
        vm: NewsListViewModel.shared,
        systemColorScheme: .dark,
        showPaywall: {}
    )
}
