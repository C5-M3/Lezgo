//
//  TripMapViewModelCarCameraTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The camera while a car status card opens and closes (`specs/UserStories.md` → US-06, "Car status"). Agus, the
/// leader, uses this phone and taps the other cars.
struct TripMapViewModelCarCameraTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel() -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: [Fixtures.State()]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
    }

    @Test func TappingACarLeavesTheCameraWhereItIs() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.ShowWholeRoute()

        viewModel.SelectCar(Fixtures.budiID)

        #expect(viewModel.cameraMode == .wholeRoute)
    }

    @Test func ClosingTheCardLeavesTheCameraWhereItIs() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)

        viewModel.SelectCar(nil)

        #expect(viewModel.cameraMode == .followMyCar)
    }
}
