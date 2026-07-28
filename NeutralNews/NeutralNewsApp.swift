//
//  NeutralNewsApp.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseCrashlytics
import RevenueCat

@main
struct NeutralNewsApp: App {
#if DEBUG
    private static let debugRevenueCatUserDefaults =
        UserDefaults(suiteName: "dev.itram.news.revenuecat.debug") ?? .standard
#endif

    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(PushNotificationAppDelegate.self) private var pushNotificationAppDelegate
    @State private var config = AppConfig()
    @State private var wasInBackground = false
    @AppStorage(AppColorScheme.storageKey) private var appColorScheme = AppColorScheme.system.rawValue

    // Local cache container (no iCloud)
    let cacheContainer: ModelContainer = {
        do {
            let configuration = ModelConfiguration(
                schema: Schema([CachedNeutralNews.self, CachedNews.self]),
                url: URL.documentsDirectory.appending(path: "Cache.store"),
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: Schema([CachedNeutralNews.self, CachedNews.self]), configurations: [configuration])
        } catch {
            print("❌ Failed to create cache ModelContainer: \(error)")
            fatalError("Failed to create cache ModelContainer: \(error)")
        }
    }()

    init() {
        FirebaseApp.configure()
        PushNotificationService.shared.configureOnLaunch()

        // Configure Crashlytics
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #else
        // Disable Crashlytics in debug builds to avoid polluting crash reports
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif

        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String {
#if DEBUG
            let configurationBuilder = Configuration.Builder(withAPIKey: apiKey)
                .with(userDefaults: Self.debugRevenueCatUserDefaults)
#else
            let configurationBuilder = Configuration.Builder(withAPIKey: apiKey)
#endif

            let configuration = configurationBuilder
                .with(storeKitVersion: .storeKit2)
                .with(purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit2)
                .build()
            Purchases.configure(with: configuration)

            // Configure logging for debugging
            #if DEBUG
            Purchases.logLevel = .debug
            #else
            // In production/review, use less verbose logging
            Purchases.logLevel = .info
            #endif

#if DEBUG
            print("✅ RevenueCat configured with StoreKit 2 support")
#endif
        } else {
            print("❌ RevenueCat API Key not found in Info.plist")
        }

        RatingManager.shared.incrementLaunchCount()
    }

    var body: some Scene {
        WindowGroup {
            HomeView(config: config)
                .onAppear {
                    SavedNewsService.shared.prewarmStore()
                    config.startFetching()

                    // Perform cache cleanup if needed (runs in background)
                    Task {
                        await CacheService.shared.cleanExpiredCacheIfNeeded()
                    }
                    NewsDataManager.shared.refreshTodayWidgetSnapshot()
                }
                .task {
                    await PremiumManager.shared.refreshSubscriptionStatus()
                }
                .onChange(of: scenePhase) { _, newValue in
                    if newValue == .background {
                        wasInBackground = true
                        return
                    }

                    guard newValue == .active, wasInBackground else { return }
                    wasInBackground = false
                    config.startFetching()
                    PushNotificationService.shared.handleAppDidBecomeActive()

                    // Also cleanup when app returns from background
                    Task {
                        await CacheService.shared.cleanExpiredCacheIfNeeded()
                    }
                    SavedNewsService.shared.prewarmStore()
                    NewsDataManager.shared.refreshTodayWidgetSnapshot()

                    // Refresh subscription state and capture external redemptions
                    // without forcing a user-facing restore flow.
                    Task {
                        await PremiumManager.shared.refreshSubscriptionStatus()
                    }
                }
                .onOpenURL { url in
#if DEBUG
                    print("🔗 Deep link received: \(url)")
#endif
                    if url.absoluteString == WidgetDeepLink.proURL?.absoluteString {
                        PremiumManager.shared.requirePremium(for: "large_widgets")
                        return
                    }

                    // Only set loading if it's a valid deep link
                    if let deepLinkData = DeepLinkService.parseDeepLink(url) {
                        // Activate loading IMMEDIATELY to prevent showing empty state
                        NewsListViewModel.shared.isLoadingNeutralNews = true
                        NewsListViewModel.shared.handleDeepLink(deepLinkData)
                    }
                }
                .preferredColorScheme(isDarkModeForced ? .dark : nil)
        }
        .modelContainer(cacheContainer)
    }

    private var isDarkModeForced: Bool {
        AppColorScheme(rawValue: appColorScheme) == .dark
    }
}
