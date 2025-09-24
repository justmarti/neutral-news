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
import RevenueCat

@main
struct NeutralNewsApp: App {
    @State private var config = AppConfig()

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

        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String {
            Purchases.configure(with: .init(withAPIKey: apiKey))
        }
    }


    var body: some Scene {
        WindowGroup {
            HomeView(config: config)
                .onAppear {
                    // Inject Core Data context
                    NewsListViewModel.shared.coreDataContext = CoreDataManager.shared.viewContext
                    config.startFetching()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    config.startFetching()
                }
                .onOpenURL { url in
#if DEBUG
                    print("🔗 Deep link received: \(url)")
#endif
                    if let deepLinkData = DeepLinkService.parseDeepLink(url) {
                        NewsListViewModel.shared.handleDeepLink(deepLinkData)
                    }
                }
        }
        .modelContainer(cacheContainer)
    }
}
