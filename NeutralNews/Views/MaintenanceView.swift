//
//  MaintenanceView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 6/8/25.
//

import SwiftUI

struct MaintenanceView: View {
    let config: AppConfig
    
    var body: some View {
        ScrollView {
            ContentUnavailableView(
                "Under maintenance",
                systemImage: "gearshape.2.fill",
                description: Text("Everything will be ready soon. Thanks for your patience.")
            )
            .containerRelativeFrame([.horizontal, .vertical])
        }
        .refreshable {
            config.startFetching()
        }
    }
}

#Preview {
    MaintenanceView(config: AppConfig(isTestMode: true))
}
