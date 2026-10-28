//
//  LezgoApp.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 20/10/26.
//

import SwiftUI

@main
struct LezgoApp: App {
    /// Every screen reads this through `@Environment(\.tripService)` (ADR 0017). Trips sync through CloudKit
    /// (ADR 0014); previews and tests use `InMemoryTripService` instead.
    private let tripService: any TripService = LiveTripService(database: LiveCloudDatabase())

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // Launched with `-DebugScreen <name>`: open that screen with simulated data. See `DebugScreen` for how
            // to set this up in your own unshared scheme. Without the argument, and in every release build, the app
            // starts normally.
            if let debugScreen = DebugScreen.FromLaunchArguments() {
                debugScreen.MakeView()
            } else {
                HomeView()
            }
            #else
            HomeView()
            #endif
        }
        .environment(\.tripService, tripService)
    }
}
