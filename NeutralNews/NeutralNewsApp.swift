//
//  NeutralNewsApp.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI
import SwiftData
import CoreData
import FirebaseCore
import FirebaseCrashlytics
import RevenueCat

@main
struct NeutralNewsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var config = AppConfig()
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

        // Configure Crashlytics
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #else
        // Disable Crashlytics in debug builds to avoid polluting crash reports
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif

        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String {
            let configuration = Configuration.Builder(withAPIKey: apiKey)
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
                    // Inject Core Data context
                    NewsListViewModel.shared.coreDataContext = CoreDataManager.shared.viewContext
                    config.startFetching()

                    // Perform cache cleanup if needed (runs in background)
                    CacheService.shared.cleanExpiredCacheIfNeeded()
                }
                .onChange(of: scenePhase) { oldValue, newValue in
                    guard oldValue == .background, newValue == .active else { return }
                    config.startFetching()

                    // Also cleanup when app returns from background
                    CacheService.shared.cleanExpiredCacheIfNeeded()

                    // Refresh subscription state and capture external redemptions
                    // without forcing a user-facing restore flow.
                    Task {
                        await PremiumManager.shared.refreshSubscriptionStatusAfterActivation()
                    }
                }
                .onOpenURL { url in
#if DEBUG
                    print("🔗 Deep link received: \(url)")
#endif
                    // Only set loading if it's a valid deep link
                    if let deepLinkData = DeepLinkService.parseDeepLink(url) {
                        // Activate loading IMMEDIATELY to prevent showing empty state
                        NewsListViewModel.shared.isLoadingNeutralNews = true
                        NewsListViewModel.shared.handleDeepLink(deepLinkData)
                    }
                }
                .preferredColorScheme(AppColorScheme(rawValue: appColorScheme)?.colorScheme)
        }
        .modelContainer(cacheContainer)
    }
}
