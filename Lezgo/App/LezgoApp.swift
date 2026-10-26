//
//  LezgoApp.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 20/10/26.
//

import SwiftUI
import SwiftData

@main
struct LezgoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self
        ])
        // The app has a CloudKit entitlement for trip sync (ADR 0014). Without `.none`, SwiftData would also
        // try to mirror this local store to the private database and fail on models CloudKit cannot store.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
        .modelContainer(sharedModelContainer)
        .environment(\.tripService, tripService)
    }
}
