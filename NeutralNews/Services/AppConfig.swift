//
//  AppConfig.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 6/8/25.
//

import Foundation
import FirebaseRemoteConfig

@MainActor
final class AppConfig: ObservableObject {
    @Published var isInMaintenance: Bool = false
    
    private let remoteConfig: RemoteConfig?
    
    init(isTestMode: Bool = false) {
        if isTestMode {
            self.remoteConfig = nil
            self.isInMaintenance = false
        } else {
            self.remoteConfig = RemoteConfig.remoteConfig()
            self.remoteConfig?.setDefaults(["maintenance_mode": false as NSObject])
        }
    }
    
    func startFetching() {
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
