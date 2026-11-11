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

    @Test func ZoomingInMovesTheCameraCloserAndStopsAtTheMinimum() {
        let viewModel = MakeViewModel()
        #expect(viewModel.followDistance == TripMapCamera.defaultFollowDistance)

        viewModel.ZoomIn()
        #expect(viewModel.followDistance < TripMapCamera.defaultFollowDistance)

        for _ in 0..<20 { viewModel.ZoomIn() }
        #expect(viewModel.followDistance == TripMapCamera.minFollowDistance)
        #expect(viewModel.cameraMode == .followMyCar)
    }

    @Test func ZoomingOutMovesTheCameraBackAndStopsAtTheMaximum() {
        let viewModel = MakeViewModel()

        viewModel.ZoomOut()
        #expect(viewModel.followDistance > TripMapCamera.defaultFollowDistance)

        for _ in 0..<20 { viewModel.ZoomOut() }
        #expect(viewModel.followDistance == TripMapCamera.maxFollowDistance)
        #expect(viewModel.cameraMode == .followMyCar)
    }

    @Test func MapReportRightAfterZoomingKeepsFollowingMyCar() {
        var now = Fixtures.now
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: [Fixtures.State()]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { now }
        )

        viewModel.ZoomIn()
        now += 0.5
        viewModel.StopFollowing()

        #expect(viewModel.cameraMode == .followMyCar)
    }

    @Test func MyHeadingFollowsMyDrivingCourse() async {
        var agus = Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        agus.course = 135
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: [Fixtures.State(cars: [agus])]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService()
        )

        await viewModel.Start()

        #expect(viewModel.myHeading == 135)
        #expect(viewModel.carPins.first { $0.isMe }?.course == 135)
    }

    @Test func StoppedCarLooksForwardAlongTheRouteAhead() async throws {
        var agus = Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        agus.course = nil
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: [Fixtures.State(cars: [agus])]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService()
        )

        await viewModel.Start()

        let me = try #require(viewModel.carPins.first { $0.isMe })
        #expect(viewModel.myHeading > 0)
        #expect(me.course == viewModel.myHeading)
    }

    @Test func MarkerScaleAdjustsToScreenRatioOnSmallAndLargeDisplays() {
        let smallCarPlayScale = TripMapCamera.MarkerScale(mapWidth: 374, mapHeight: 228)
        let widescreenCarPlayScale = TripMapCamera.MarkerScale(mapWidth: 800, mapHeight: 450)
        let phoneScale = TripMapCamera.MarkerScale(mapWidth: 402, mapHeight: 874)

        #expect(smallCarPlayScale < 0.45)
        #expect(smallCarPlayScale < widescreenCarPlayScale)
        #expect(smallCarPlayScale < phoneScale)
        let groupScale = TripMapCamera.MarkerScale(mapWidth: 374, mapHeight: 228, carCount: 2)
        #expect(groupScale < smallCarPlayScale)
    }

    @Test func MarkerScaleShrinksWhenZoomedOutSoRouteRemainsVisible() {
        let normalScale = TripMapCamera.MarkerScale(
            mapWidth: 374,
            mapHeight: 228,
            cameraDistance: TripMapCamera.defaultFollowDistance
        )
        let zoomedOutScale = TripMapCamera.MarkerScale(
            mapWidth: 374,
            mapHeight: 228,
            cameraDistance: TripMapCamera.defaultFollowDistance * 4
        )

        #expect(zoomedOutScale < normalScale)
    }
}
