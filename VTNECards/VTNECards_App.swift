//
//  VTNECards_App.swift
//  VTNECards
//
//  Created by David Cardona on 11/16/25.
//

import SwiftUI

@main
struct VTNECardsApp: App {
    @StateObject private var dataSync = DataSyncManager.shared

    var body: some Scene {
        WindowGroup {
            LandingView()
                .environmentObject(dataSync)
                .task {
                    await dataSync.syncIfNeeded()
                }
        }
    }
}
