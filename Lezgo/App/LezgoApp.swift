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
    /// Mirrors the open trip map on the Lock Screen and in the Dynamic Island (ADR 0027).
    private let tripActivityUpdater = TripActivityUpdater(activity: LiveTripLiveActivity())

    init() {
        ToggleTripMuteIntent.toggle = { ActiveTripMap.shared.tripMap?.sound.ToggleMute() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { await tripActivityUpdater.Run(following: .shared) }
        }
        .environment(\.tripService, tripService)
    }
}

/// The first screen: Home, or a debug screen picked by a launch argument.
private struct RootView: View {
    var isUITestingSetRouteMap: Bool {
        CommandLine.arguments.contains("-ui-testing-set-route-map")
    }

    var body: some View {
        Group {
            #if DEBUG
            // Launched with `-DebugScreen <name>`: open that screen with simulated data. See `DebugScreen` for how
            // to set this up in your own unshared scheme. Without the argument, and in every release build, the app
            // starts normally.
            if let debugScreen = DebugScreen.FromLaunchArguments() {
                debugScreen.MakeView()
            } else if isUITestingSetRouteMap {
                SetRouteMapView()
            } else {
                HomeView()
            }
            #else
            HomeView()
            #endif
        }
    }
}
