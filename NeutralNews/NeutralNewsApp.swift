//
//  NeutralNewsApp.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 12/17/24.
//

import SwiftUI
import FirebaseCore

@main
struct NeutralNewsApp: App {
    @StateObject private var config = AppConfig()
    
    init() { FirebaseApp.configure() }
    
    var body: some Scene {
        WindowGroup {
            HomeView(config: config)
                .onAppear {
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
    }
}
