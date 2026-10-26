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

    /// Every screen reads this through `@Environment(\.tripService)` (ADR 0017). Trips stay on this phone until
    /// `LiveTripService` (#65) replaces it here.
    private let tripService: any TripService = InMemoryTripService()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environment(\.tripService, tripService)
    }
}
