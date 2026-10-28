//
//  TripMapViewModelCarCameraTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The camera and the follow button on the car status card (`specs/UserStories.md` → US-06, "Car status"). Agus,
/// the leader, uses this phone and taps the other cars.
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

    private func Coordinate(of carID: UUID) throws -> Lezgo.Coordinate {
        try #require(Fixtures.State().participants.first { $0.id == carID }?.coordinate)
    }

    @Test func FollowButtonKeepsTheCameraOnTheTappedCar() async throws {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)

        viewModel.FollowSelectedCar()

        let budi = try Coordinate(of: Fixtures.budiID)
        #expect(viewModel.cameraMode == .followCar(Fixtures.budiID))
        #expect(viewModel.followedCoordinate == budi)
    }

    @Test func PressingFollowAgainStopsFollowingAndReturnsToMyCar() async throws {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)
        viewModel.FollowSelectedCar()

        viewModel.FollowSelectedCar()

        let agus = try Coordinate(of: Fixtures.agusID)
        #expect(viewModel.cameraMode == .followMyCar)
        #expect(viewModel.followedCoordinate == agus)
        #expect(viewModel.selectedCarStatus?.id == Fixtures.budiID)
    }

    @Test func FollowButtonDoesNothingWithoutATappedCar() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.ShowWholeRoute()

        viewModel.FollowSelectedCar()

        #expect(viewModel.cameraMode == .wholeRoute)
    }

    @Test func CameraFollowingMyCarStaysOnMyCar() async throws {
        let viewModel = MakeViewModel()
        await viewModel.Start()

        let agus = try Coordinate(of: Fixtures.agusID)
        #expect(viewModel.cameraMode == .followMyCar)
        #expect(viewModel.followedCoordinate == agus)
    }

    @Test func CameraThatFollowsNoCarHasNoFollowedPosition() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()

        viewModel.ShowWholeRoute()

        #expect(viewModel.followedCoordinate == nil)
    }

    @Test func ClosingTheCardReturnsTheCameraToMyCar() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)
        viewModel.FollowSelectedCar()

        viewModel.SelectCar(nil)

        #expect(viewModel.cameraMode == .followMyCar)
    }

    @Test func ClosingTheCardLeavesACameraThatDidNotFollowTheCar() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.ShowWholeRoute()
        viewModel.SelectCar(Fixtures.budiID)

        viewModel.SelectCar(nil)

        #expect(viewModel.cameraMode == .wholeRoute)
    }

    @Test func TappingAnotherCarStopsFollowingTheFirstWhereItIs() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)
        viewModel.FollowSelectedCar()

        viewModel.SelectCar(Fixtures.citraID)

        #expect(viewModel.cameraMode == .free)
        #expect(viewModel.selectedCarStatus?.id == Fixtures.citraID)
    }
}
