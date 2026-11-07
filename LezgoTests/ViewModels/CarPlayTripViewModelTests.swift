//
//  CarPlayTripViewModelTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// What CarPlay shows of the trip map open on the phone (ADR 0023, #257).
struct CarPlayTripViewModelTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeTripMap(
        me: UUID = Fixtures.budiID,
        states: [TripState],
        service: MockTripService? = nil,
        guidance: TripMapGuidance = Fixtures.Guidance()
    ) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: service ?? MockTripService(states: states),
            navigator: MockTripMapNavigator(results: [.success(guidance)]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
    }

    /// A CarPlay view model mirroring `tripMap`, after the trip map has read every state.
    private func MakeViewModel(mirroring tripMap: TripMapViewModel) async -> CarPlayTripViewModel {
        let activeTripMap = ActiveTripMap()
        activeTripMap.Show(tripMap)
        await tripMap.Start()
        return CarPlayTripViewModel(activeTripMap: activeTripMap)
    }

    private func ArrivedState(citraMetres: Double) -> TripState {
        Fixtures.State(cars: [
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: 5),
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: citraMetres)
        ])
    }

    // MARK: No trip

    @Test func WithoutATripMapOnThePhoneThereIsNoTrip() {
        let viewModel = CarPlayTripViewModel(activeTripMap: ActiveTripMap())

        #expect(viewModel.screen == .noTrip)
        #expect(viewModel.maneuver == nil)
        #expect(viewModel.tripEstimate == nil)
        #expect(viewModel.leaveButtonTitle == nil)
        #expect(viewModel.cars.isEmpty)
    }

    @Test func TripMapWaitingForItsFirstUpdateIsLoading() {
        let activeTripMap = ActiveTripMap()
        activeTripMap.Show(MakeTripMap(states: []))

        let viewModel = CarPlayTripViewModel(activeTripMap: activeTripMap)

        #expect(viewModel.screen == .loading)
    }

    @Test func TripMapThatClosedOnThePhoneIsNoTrip() async {
        let tripMap = MakeTripMap(states: [Fixtures.State()])
        let viewModel = await MakeViewModel(mirroring: tripMap)

        viewModel.RequestLeave()
        await viewModel.ConfirmLeave()

        #expect(viewModel.screen == .noTrip)
    }

    // MARK: On the way

    @Test func OnTheWayShowsTheNextTurn() async throws {
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(states: [Fixtures.State()]))

        let maneuver = try #require(viewModel.maneuver)
        #expect(viewModel.screen == .onTheWay)
        #expect(maneuver.instructionVariants == ["Turn right"])
        #expect(maneuver.distance == Measurement(value: 200, unit: .meters))
        #expect(maneuver.symbolName == "arrow.turn.up.right")
    }

    /// MapKit often gives the first step no text; CarPlay needs at least one instruction.
    @Test func TurnWithoutAnInstructionNamesTheDestination() async throws {
        var guidance = Fixtures.Guidance()
        guidance.instruction = ""
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(states: [Fixtures.State()], guidance: guidance))

        let maneuver = try #require(viewModel.maneuver)
        #expect(maneuver.instructionVariants == [String(localized: .tripMapToDestination("Pakuwon mall"))])
    }

    @Test func TripEstimateShowsTheTimeAndDistanceLeft() async throws {
        var guidance = Fixtures.Guidance(minutesLeft: 50)
        guidance.distanceLeft = Measurement(value: 12, unit: .kilometers)
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(states: [Fixtures.State()], guidance: guidance))

        let estimate = try #require(viewModel.tripEstimate)
        #expect(estimate.timeLeft == .seconds(3_000))
        #expect(estimate.distanceLeft == Measurement(value: 12, unit: .kilometers))
        #expect(viewModel.destinationName == "Pakuwon mall")
    }

    // MARK: Leave and end

    @Test func MemberSeesExitTrip() async {
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(me: Fixtures.budiID, states: [Fixtures.State()]))

        #expect(viewModel.leaveButtonTitle == .tripMapExitTrip)
    }

    @Test func LeaderSeesEndTrip() async {
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(me: Fixtures.agusID, states: [Fixtures.State()]))

        #expect(viewModel.leaveButtonTitle == .tripMapEndTrip)
    }

    @Test func MemberIsAskedBeforeExiting() async throws {
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(me: Fixtures.budiID, states: [Fixtures.State()]))

        viewModel.RequestLeave()

        let confirmation = try #require(viewModel.leaveConfirmation)
        #expect(confirmation.title == String(localized: .tripMapExitTripQuestion))
        #expect(confirmation.message == String(localized: .tripMapExitTripMessage))
        #expect(confirmation.isDestructive == false)
    }

    @Test func LeaderIsWarnedThatNotEveryoneHasArrived() async throws {
        let tripMap = MakeTripMap(me: Fixtures.agusID, states: [ArrivedState(citraMetres: 500)])
        let viewModel = await MakeViewModel(mirroring: tripMap)

        viewModel.RequestLeave()

        let confirmation = try #require(viewModel.leaveConfirmation)
        #expect(confirmation.title == String(localized: .tripMapEndTripQuestion))
        #expect(confirmation.message == String(localized: .tripMapEndTripNotEveryoneMessage))
        #expect(confirmation.isDestructive)
    }

    @Test func CancelKeepsTheTrip() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(states: [], service: service))

        viewModel.RequestLeave()
        viewModel.CancelLeave()

        #expect(viewModel.leaveConfirmation == nil)
        #expect(service.exitedParticipantIDs.isEmpty)
    }

    @Test func ConfirmExitsTheTrip() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(me: Fixtures.budiID, states: [], service: service))

        viewModel.RequestLeave()
        await viewModel.ConfirmLeave()

        #expect(service.exitedParticipantIDs == [Fixtures.budiID])
    }

    @Test func ConfirmWithoutAQuestionDoesNothing() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(states: [], service: service))

        await viewModel.ConfirmLeave()

        #expect(service.exitedParticipantIDs.isEmpty)
    }

    // MARK: Alerts

    @Test func AnotherCarOffTheRouteIsAnAlert() async throws {
        var citra = Fixtures.Car(id: Fixtures.citraID, name: "Citra", latitude: -7.2750)
        citra.alert = .offRoute
        let state = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus", latitude: -7.2650),
            Fixtures.Car(id: Fixtures.budiID, name: "Budi", latitude: -7.2700),
            citra
        ])
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(me: Fixtures.agusID, states: [state]))

        let alert = try #require(viewModel.alert)
        #expect(alert == .banner(.otherCar(id: Fixtures.citraID, name: "Citra", alert: .offRoute)))
        #expect(viewModel.AlertTitle(alert) == String(localized: .tripMapAlertCarOffRoute("Citra")))
    }

    @Test func ClosedAlertGoesAway() async throws {
        var citra = Fixtures.Car(id: Fixtures.citraID, name: "Citra", latitude: -7.2750)
        citra.alert = .offRoute
        let state = Fixtures.State(cars: [Fixtures.Car(id: Fixtures.agusID, name: "Agus"), citra])
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(me: Fixtures.agusID, states: [state]))

        viewModel.DismissAlert(try #require(viewModel.alert))

        #expect(viewModel.alert == nil)
    }

    @Test func NoAlertWhileEveryoneIsInFormation() async {
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(states: [Fixtures.State()]))

        #expect(viewModel.alert == nil)
    }

    // MARK: Arrival

    @Test func ArrivedMemberWaitsForEveryone() async throws {
        let tripMap = MakeTripMap(me: Fixtures.budiID, states: [ArrivedState(citraMetres: 500)])
        let viewModel = await MakeViewModel(mirroring: tripMap)

        let arrival = try #require(viewModel.arrival)
        #expect(viewModel.screen == .arrived)
        #expect(arrival.title == String(localized: .tripMapYouHaveArrived))
        #expect(arrival.subtitle == String(localized: .tripMapWaitingForEveryone))
        #expect(arrival.count == "2/3")
    }

    @Test func EveryoneArrived() async throws {
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(states: [ArrivedState(citraMetres: 10)]))

        let arrival = try #require(viewModel.arrival)
        #expect(arrival.title == String(localized: .tripMapEveryoneHasArrived))
        #expect(arrival.count == "3/3")
    }

    @Test func OnTheWayThereIsNoArrival() async {
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(states: [Fixtures.State()]))

        #expect(viewModel.arrival == nil)
    }

    // MARK: Cars

    @Test func CarsListTheLeaderFirst() async {
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(me: Fixtures.budiID, states: [Fixtures.State()]))

        #expect(viewModel.cars.map(\.name) == ["Agus", "Budi", "Citra"])
        #expect(viewModel.cars.map(\.isLeader) == [true, false, false])
        #expect(viewModel.cars.map(\.isMe) == [false, true, false])
    }

    /// A CarPlay map panel holds at most 12 items.
    @Test func CarsStopAtTwelve() async {
        let cars = (0..<14).map { Fixtures.Car(id: UUID(), name: "Car \($0)") }
            + [Fixtures.Car(id: Fixtures.agusID, name: "Agus"), Fixtures.Car(id: Fixtures.budiID, name: "Budi")]
        let viewModel = await MakeViewModel(mirroring: MakeTripMap(states: [Fixtures.State(cars: cars)]))

        #expect(viewModel.cars.count == 12)
        #expect(viewModel.cars.first?.name == "Agus")
    }

    @Test func PickingACarOpensItsStatusAndFocusesTheCamera() async throws {
        let tripMap = MakeTripMap(me: Fixtures.budiID, states: [Fixtures.State()])
        let viewModel = await MakeViewModel(mirroring: tripMap)

        viewModel.SelectCar(Fixtures.citraID)

        let status = try #require(viewModel.selectedCar)
        #expect(status.displayName == "Citra")
        #expect(tripMap.cameraMode == .followCar(Fixtures.citraID))
    }

    @Test func ClosingTheCarGoesBackToMyCar() async {
        let tripMap = MakeTripMap(me: Fixtures.budiID, states: [Fixtures.State()])
        let viewModel = await MakeViewModel(mirroring: tripMap)
        viewModel.SelectCar(Fixtures.citraID)

        viewModel.SelectCar(nil)

        #expect(viewModel.selectedCar == nil)
        #expect(tripMap.cameraMode == .followMyCar)
    }

    // MARK: Map buttons

    @Test func MapButtonsMoveTheCamera() async {
        let tripMap = MakeTripMap(states: [Fixtures.State()])
        let viewModel = await MakeViewModel(mirroring: tripMap)

        viewModel.ShowWholeRoute()
        #expect(tripMap.cameraMode == .wholeRoute)

        viewModel.FollowMyCar()
        #expect(tripMap.cameraMode == .followMyCar)
    }
}
