//
//  MapViewModelLocationTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 19/11/26.
//

import Testing
@testable import Lezgo

/// Set Route uses the GPS only while it is shown with the app in front: a GPS left running keeps the location arrow
/// in the Dynamic Island while the app is in the background.
@MainActor
struct MapViewModelLocationTests {
    /// Set Route is built hidden on Home ahead of time, so appearing must not start the GPS; the screen starts it
    /// once it is really shown.
    @Test func OnAppearDoesNotStartTheLocation() {
        let viewModel = MapViewModel()

        viewModel.onAppear()

        #expect(viewModel.locationService.isWanted == false)
    }

    @Test func StartAndStopLocationFollowTheScreen() {
        let viewModel = MapViewModel()

        viewModel.StartLocation()
        #expect(viewModel.locationService.isWanted)
        viewModel.StopLocation()

        #expect(viewModel.locationService.isWanted == false)
    }
}
