//
//  AppConfig.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 6/8/25.
//

import Foundation
import FirebaseRemoteConfig

@Observable
@MainActor
final class AppConfig {
    var isInMaintenance: Bool = false
    
    private var remoteConfig: RemoteConfig?
    private let isTestMode: Bool

    init(isTestMode: Bool = false) {
        self.isTestMode = isTestMode
        self.isInMaintenance = false
    }
    
    func startFetching() {
        if !isTestMode && remoteConfig == nil {
            remoteConfig = RemoteConfig.remoteConfig()
            remoteConfig?.setDefaults(["maintenance_mode": false as NSObject])
        }

        guard let remoteConfig else { return }
        
        Task {
            await fetchRemoteConfig(remoteConfig)
        }
    }
    
    private func fetchRemoteConfig(_ remoteConfig: RemoteConfig) async {
        do {
            let settings = RemoteConfigSettings()
            settings.minimumFetchInterval = 60
            remoteConfig.configSettings = settings
            
            _ = try await remoteConfig.fetchAndActivate()
            isInMaintenance = remoteConfig["maintenance_mode"].boolValue
        } catch {
#if DEBUG
            print("⚠️ Remote Config fetch error: \(error.localizedDescription)")
#endif
        }
    }
}
