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
        activeTripMap.Show(Fixtures.TripMap(states: []))

        let viewModel = CarPlayTripViewModel(activeTripMap: activeTripMap)

        #expect(viewModel.screen == .loading)
    }

    @Test func TripMapThatClosedOnThePhoneIsNoTrip() async {
        let tripMap = Fixtures.TripMap(states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        viewModel.RequestLeave()
        await viewModel.ConfirmLeave()

        #expect(viewModel.screen == .noTrip)
    }

    // MARK: On the way

    @Test func OnTheWayShowsTheNextTurn() async throws {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

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
        let tripMap = Fixtures.TripMap(states: [Fixtures.State()], guidance: guidance)
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        let maneuver = try #require(viewModel.maneuver)
        #expect(maneuver.instructionVariants == [String(localized: .tripMapToDestination("Pakuwon mall"))])
    }

    @Test func TripEstimateShowsTheTimeAndDistanceLeft() async throws {
        var guidance = Fixtures.Guidance(minutesLeft: 50)
        guidance.distanceLeft = Measurement(value: 12, unit: .kilometers)
        let tripMap = Fixtures.TripMap(states: [Fixtures.State()], guidance: guidance)
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        let estimate = try #require(viewModel.tripEstimate)
        #expect(estimate.timeLeft == .seconds(3_000))
        #expect(estimate.distanceLeft == Measurement(value: 12, unit: .kilometers))
        #expect(viewModel.destinationName == "Pakuwon mall")
    }

    /// The simulated drive, and some routes, give no distance left; CarPlay must not say "0 km" then.
    @Test func DistanceLeftFallsBackToTheRouteAhead() async throws {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

        let distanceLeft = try #require(viewModel.tripEstimate?.distanceLeft)
        #expect(distanceLeft.converted(to: .kilometers).value > 1)
    }

    // MARK: Leave and end

    @Test func MemberSeesExitTrip() async {
        let tripMap = Fixtures.TripMap(me: Fixtures.budiID, states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        #expect(viewModel.leaveButtonTitle == .tripMapExitTrip)
    }

    @Test func LeaderSeesEndTrip() async {
        let tripMap = Fixtures.TripMap(me: Fixtures.agusID, states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        #expect(viewModel.leaveButtonTitle == .tripMapEndTrip)
    }

    @Test func MemberIsAskedBeforeExiting() async throws {
        let tripMap = Fixtures.TripMap(me: Fixtures.budiID, states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        viewModel.RequestLeave()

        let confirmation = try #require(viewModel.leaveConfirmation)
        #expect(confirmation.title == String(localized: .tripMapExitTripQuestion))
        #expect(confirmation.message == String(localized: .tripMapExitTripMessage))
        #expect(confirmation.isDestructive == false)
    }

    @Test func LeaderIsWarnedThatNotEveryoneHasArrived() async throws {
        let tripMap = Fixtures.TripMap(me: Fixtures.agusID, states: [Fixtures.ArrivedState(citraMetres: 500)])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        viewModel.RequestLeave()

        let confirmation = try #require(viewModel.leaveConfirmation)
        #expect(confirmation.title == String(localized: .tripMapEndTripQuestion))
        #expect(confirmation.message == String(localized: .tripMapEndTripNotEveryoneMessage))
        #expect(confirmation.isDestructive)
    }

    @Test func CancelKeepsTheTrip() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [], service: service))

        viewModel.RequestLeave()
        viewModel.CancelLeave()

        #expect(viewModel.leaveConfirmation == nil)
        #expect(service.exitedParticipantIDs.isEmpty)
    }

    @Test func ConfirmExitsTheTrip() async {
        let service = MockTripService(states: [Fixtures.State()])
        let tripMap = Fixtures.TripMap(me: Fixtures.budiID, states: [], service: service)
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        viewModel.RequestLeave()
        await viewModel.ConfirmLeave()

        #expect(service.exitedParticipantIDs == [Fixtures.budiID])
    }

    @Test func ConfirmWithoutAQuestionDoesNothing() async {
        let service = MockTripService(states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [], service: service))

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
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(me: Fixtures.agusID, states: [state]))

        let alert = try #require(viewModel.alert)
        #expect(alert == .banner(.otherCar(id: Fixtures.citraID, name: "Citra", alert: .offRoute)))
        #expect(viewModel.AlertTitle(alert) == String(localized: .tripMapAlertCarOffRoute("Citra")))
    }

    @Test func ClosedAlertGoesAway() async throws {
        var citra = Fixtures.Car(id: Fixtures.citraID, name: "Citra", latitude: -7.2750)
        citra.alert = .offRoute
        let state = Fixtures.State(cars: [Fixtures.Car(id: Fixtures.agusID, name: "Agus"), citra])
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(me: Fixtures.agusID, states: [state]))

        viewModel.DismissAlert(try #require(viewModel.alert))

        #expect(viewModel.alert == nil)
    }

    @Test func NoAlertWhileEveryoneIsInFormation() async {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

        #expect(viewModel.alert == nil)
    }

    // MARK: Arrival

    @Test func ArrivedMemberWaitsForEveryone() async throws {
        let tripMap = Fixtures.TripMap(me: Fixtures.budiID, states: [Fixtures.ArrivedState(citraMetres: 500)])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        let arrival = try #require(viewModel.arrival)
        #expect(viewModel.screen == .arrived)
        #expect(arrival.title == String(localized: .tripMapYouHaveArrived))
        #expect(arrival.subtitle == String(localized: .tripMapWaitingForEveryone))
        #expect(arrival.count == "2/3")
    }

    @Test func EveryoneArrived() async throws {
        let tripMap = Fixtures.TripMap(states: [Fixtures.ArrivedState(citraMetres: 10)])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        let arrival = try #require(viewModel.arrival)
        #expect(arrival.title == String(localized: .tripMapEveryoneHasArrived))
        #expect(arrival.count == "3/3")
    }

    @Test func OnTheWayThereIsNoArrival() async {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

        #expect(viewModel.arrival == nil)
    }

    // MARK: Cars

    @Test func CarsListTheLeaderFirst() async {
        let tripMap = Fixtures.TripMap(me: Fixtures.budiID, states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        #expect(viewModel.cars.map(\.name) == ["Agus", "Budi", "Citra"])
        #expect(viewModel.cars.map(\.isLeader) == [true, false, false])
        #expect(viewModel.cars.map(\.isMe) == [false, true, false])
    }

    /// A CarPlay map panel holds at most 12 items.
    @Test func CarsStopAtTwelve() async {
        let cars = (0..<14).map { Fixtures.Car(id: UUID(), name: "Car \($0)") }
            + [Fixtures.Car(id: Fixtures.agusID, name: "Agus"), Fixtures.Car(id: Fixtures.budiID, name: "Budi")]
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State(cars: cars)]))

        #expect(viewModel.cars.count == 12)
        #expect(viewModel.cars.first?.name == "Agus")
    }

    @Test func PickingACarOpensItsStatusAndFocusesTheCamera() async throws {
        let tripMap = Fixtures.TripMap(me: Fixtures.budiID, states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        viewModel.SelectCar(Fixtures.citraID)

        let status = try #require(viewModel.selectedCar)
        #expect(status.displayName == "Citra")
        #expect(tripMap.cameraMode == .followCar(Fixtures.citraID))
    }

    @Test func ClosingTheCarGoesBackToMyCar() async {
        let tripMap = Fixtures.TripMap(me: Fixtures.budiID, states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)
        viewModel.SelectCar(Fixtures.citraID)

        viewModel.SelectCar(nil)

        #expect(viewModel.selectedCar == nil)
        #expect(tripMap.cameraMode == .followMyCar)
    }

    // MARK: Map buttons

    @Test func MapButtonsMoveTheCamera() async {
        let tripMap = Fixtures.TripMap(states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        viewModel.ShowWholeRoute()
        #expect(tripMap.cameraMode == .wholeRoute)

        viewModel.FollowMyCar()
        #expect(tripMap.cameraMode == .followMyCar)
    }
}
