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
                "En mantenimiento",
                systemImage: "gearshape.2.fill",
                description: Text("Pronto estará todo listo, gracias por tu paciencia.")
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
