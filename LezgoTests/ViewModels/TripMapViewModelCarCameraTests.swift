//
//  TripMapViewModelCarCameraTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The camera while a car status card opens and closes: it focuses on the tapped car and goes back afterwards
/// (`specs/UserStories.md` → US-06, "Car status"). Agus, the leader, uses this phone and taps the other cars.
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

    @Test func TappingACarFocusesTheCameraOnIt() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.ToggleCamera()

        viewModel.SelectCar(Fixtures.budiID)

        #expect(viewModel.cameraMode == .followCar(Fixtures.budiID))
    }

    @Test func ClosingTheCardTakesTheCameraBackToWhereItWas() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.ToggleCamera()
        viewModel.SelectCar(Fixtures.budiID)

        viewModel.SelectCar(nil)

        #expect(viewModel.cameraMode == .wholeRoute)
    }

    @Test func TappingAnotherCarMovesTheFocusAndClosingStillGoesBack() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)

        viewModel.SelectCar(Fixtures.citraID)
        #expect(viewModel.cameraMode == .followCar(Fixtures.citraID))

        viewModel.SelectCar(nil)
        #expect(viewModel.cameraMode == .followMyCar)
    }

    @Test func TappingMyOwnCarFollowsMyCar() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.ToggleCamera()

        viewModel.SelectCar(Fixtures.agusID)
        #expect(viewModel.cameraMode == .followMyCar)

        viewModel.SelectCar(nil)
        #expect(viewModel.cameraMode == .wholeRoute)
    }

    @Test func AMapMovedByHandStaysWhereItIsWhenTheCardCloses() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)
        viewModel.StopFollowing()

        viewModel.SelectCar(nil)

        #expect(viewModel.cameraMode == .free)
    }

    @Test func ACameraButtonWhileTheCardIsOpenKeepsTheCardAndItsChoice() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)

        viewModel.ToggleCamera()
        #expect(viewModel.selectedCarID == Fixtures.budiID)
        #expect(viewModel.cameraMode == .followMyCar)

        viewModel.SelectCar(nil)
        #expect(viewModel.cameraMode == .followMyCar)
    }
}
