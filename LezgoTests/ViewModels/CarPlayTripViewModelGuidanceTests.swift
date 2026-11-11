//
//  CarPlayTripViewModelGuidanceTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Testing
import UIKit
@testable import Lezgo

/// Turn-by-turn guidance on CarPlay, and what CarPlay says when the trip closes on the phone (ADR 0023, #257).
struct CarPlayTripViewModelGuidanceTests {
    private typealias Fixtures = TripMapFixtures

    // MARK: Guidance

    @Test func WithoutATripThereIsNoGuidance() {
        let viewModel = CarPlayTripViewModel(activeTripMap: ActiveTripMap())

        #expect(viewModel.guidance == .off)
    }

    @Test func OnTheWayGuidanceShowsTheNextTurn() async throws {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

        let maneuver = try #require(viewModel.maneuver)
        #expect(viewModel.guidance == .turn(maneuver))
    }

    @Test func GuidanceWaitsForTheFirstTurn() async {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()], guidance: nil))

        #expect(viewModel.guidance == .loading)
    }

    @Test func ArrivedCarHasNoGuidance() async {
        let tripMap = Fixtures.TripMap(states: [Fixtures.ArrivedState(citraMetres: 500)])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        #expect(viewModel.guidance == .off)
    }

    /// The car's own navigation took over: Lezgo stops at once (CarPlay Developer Guide, navigation apps).
    @Test func GuidanceCancelledByCarPlayStaysOff() async {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

        viewModel.CancelGuidance()

        #expect(viewModel.guidance == .cancelledByCarPlay)
        #expect(viewModel.canResumeGuidance)
    }

    @Test func DriverCanResumeGuidance() async throws {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))
        viewModel.CancelGuidance()

        viewModel.ResumeGuidance()

        let maneuver = try #require(viewModel.maneuver)
        #expect(viewModel.guidance == .turn(maneuver))
        #expect(viewModel.canResumeGuidance == false)
    }

    @Test func NextTripStartsWithGuidance() async throws {
        let activeTripMap = ActiveTripMap()
        let first = Fixtures.TripMap(states: [Fixtures.State()])
        let viewModel = await Fixtures.CarPlay(mirroring: first, on: activeTripMap)
        viewModel.CancelGuidance()
        activeTripMap.Hide(first)

        let next = Fixtures.TripMap(states: [Fixtures.State()])
        activeTripMap.Show(next)
        await next.Start()

        #expect(viewModel.guidance == .turn(try #require(viewModel.maneuver)))
    }

    @Test func GuidedTripEndsAtTheDestinationStop() async {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

        #expect(viewModel.destinationCoordinate == Fixtures.destination.coordinate)
    }

    /// Above 50 pt wide, CarPlay treats the arrow as a wide image and puts it on top of the distance alone, which
    /// makes the turn card tall on small (@2x) CarPlay screens.
    @Test(arguments: [
        "arrow.up",
        "arrow.turn.up.left",
        "arrow.turn.up.right",
        "arrow.uturn.down",
        "flag.checkered"
    ])
    func ManeuverSymbolFitsBesideTheDistanceOnSmallScreens(symbolName: String) throws {
        let symbol = try #require(CarPlayTripMapTemplate.ManeuverSymbol(symbolName, scale: 2))
        let cgImage = try #require(symbol.cgImage)
        let widthOnSmallScreen = CGFloat(cgImage.width) / 2

        #expect(symbol.size.width <= CarPlayTripMapTemplate.maxCompactManeuverSymbolWidth)
        #expect(widthOnSmallScreen <= CarPlayTripMapTemplate.maxCompactManeuverSymbolWidth)
    }

    // MARK: Trip closed on the phone

    @Test(arguments: [TripStatus.ended, .cancelled])
    func LeaderEndingTheTripIsToldOnCarPlay(status: TripStatus) async {
        let states = [Fixtures.State(), Fixtures.State(status: status)]
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(me: Fixtures.budiID, states: states))

        #expect(viewModel.screen == .noTrip)
        #expect(viewModel.closeMessage == String(localized: .tripMapLeaderEndedTrip))
    }

    @Test func RemovedMemberIsToldOnCarPlay() async {
        let withoutBudi = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus"),
            Fixtures.Car(id: Fixtures.citraID, name: "Citra")
        ])
        let tripMap = Fixtures.TripMap(me: Fixtures.budiID, states: [Fixtures.State(), withoutBudi])
        let viewModel = await Fixtures.CarPlay(mirroring: tripMap)

        #expect(viewModel.closeMessage == String(localized: .tripMapRemovedFromTrip))
    }

    /// The driver chose Exit Trip themself, so there is nothing to tell them.
    @Test func OwnExitHasNoMessage() async {
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(states: [Fixtures.State()]))

        viewModel.RequestLeave()
        await viewModel.ConfirmLeave()

        #expect(viewModel.closeMessage == nil)
    }

    @Test func ClosedMessageGoesAway() async {
        let states = [Fixtures.State(), Fixtures.State(status: .ended)]
        let viewModel = await Fixtures.CarPlay(mirroring: Fixtures.TripMap(me: Fixtures.budiID, states: states))

        viewModel.DismissCloseMessage()

        #expect(viewModel.closeMessage == nil)
    }
}
