//
//  TripMapAlertsStoppedTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// "Citra has stopped": another car that was driving has stopped on the way (`specs/UserStories.md` → US-06).
struct TripMapAlertsStoppedTests {
    private typealias Fixtures = TripMapFixtures

    private func State(citra: MotionState, citraMetres: Double = 5_000, lastSeenSecondsAgo: Double = 1) -> TripState {
        var car = Fixtures.CarNearDestination(
            id: Fixtures.citraID,
            name: "Citra",
            metres: citraMetres,
            lastSeenSecondsAgo: lastSeenSecondsAgo
        )
        car.motionState = citra
        return Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus", motionState: .driving),
            Fixtures.Car(id: Fixtures.budiID, name: "Budi", motionState: .driving),
            car
        ])
    }

    /// Alerts that have seen Citra drive and then stop.
    private func AlertsAfterDrivingThenStopping() -> TripMapAlerts {
        var alerts = TripMapAlerts(myParticipantID: Fixtures.budiID)
        _ = alerts.Update(State(citra: .driving))
        _ = alerts.Update(State(citra: .stopped))
        return alerts
    }

    @Test func ACarThatDroveAndStoppedGetsABanner() {
        let alerts = AlertsAfterDrivingThenStopping()

        let banner = alerts.Banner(in: State(citra: .stopped), at: Fixtures.now)

        #expect(banner == .carStopped(id: Fixtures.citraID, name: "Citra"))
    }

    @Test func ACarWaitingAtTheStartGetsNoBanner() {
        var alerts = TripMapAlerts(myParticipantID: Fixtures.budiID)
        let state = State(citra: .stopped)
        _ = alerts.Update(state)

        #expect(alerts.Banner(in: state, at: Fixtures.now) == nil)
    }

    @Test func MyOwnCarGetsNoStoppedBanner() {
        var alerts = TripMapAlerts(myParticipantID: Fixtures.citraID)
        _ = alerts.Update(State(citra: .driving))
        let state = State(citra: .stopped)
        _ = alerts.Update(state)

        // Far from the route, my car may have its own formation alert; it must never be told it has stopped.
        if case .carStopped = alerts.Banner(in: state, at: Fixtures.now) {
            Issue.record("My own car got a stopped banner")
        }
    }

    @Test func ACarAtTheDestinationGetsNoBanner() {
        var alerts = TripMapAlerts(myParticipantID: Fixtures.budiID)
        _ = alerts.Update(State(citra: .driving))
        let state = State(citra: .stopped, citraMetres: 10)
        _ = alerts.Update(state)

        #expect(alerts.Banner(in: state, at: Fixtures.now) == nil)
    }

    /// Parked 200 m from a point on the far side of a big mall, after "I've Arrived": the car has arrived, not stopped.
    @Test func ACarThatSaidItArrivedGetsNoBanner() {
        var alerts = TripMapAlerts(myParticipantID: Fixtures.budiID)
        _ = alerts.Update(State(citra: .driving, citraMetres: 200))
        var state = State(citra: .stopped, citraMetres: 200)
        state.participants[2].arrivedAtWaypointID = Fixtures.destination.id
        _ = alerts.Update(state)

        #expect(alerts.Banner(in: state, at: Fixtures.now) == nil)
    }

    @Test func AnOfflineCarGetsNoStoppedBanner() {
        var alerts = TripMapAlerts(myParticipantID: Fixtures.budiID)
        _ = alerts.Update(State(citra: .driving))
        let state = State(citra: .stopped, lastSeenSecondsAgo: 300)
        _ = alerts.Update(state)

        #expect(alerts.Banner(in: state, at: Fixtures.now) == nil)
    }

    @Test func TheBannerGoesWhenTheCarDrivesAgain() {
        var alerts = AlertsAfterDrivingThenStopping()
        let driving = State(citra: .driving)
        _ = alerts.Update(driving)

        #expect(alerts.Banner(in: driving, at: Fixtures.now) == nil)
    }

    @Test func ClosingHidesItUntilTheCarStopsAgain() throws {
        var alerts = AlertsAfterDrivingThenStopping()
        let stopped = State(citra: .stopped)
        alerts.Close(try #require(alerts.Banner(in: stopped, at: Fixtures.now)))

        _ = alerts.Update(stopped)
        #expect(alerts.Banner(in: stopped, at: Fixtures.now) == nil)

        _ = alerts.Update(State(citra: .driving))
        _ = alerts.Update(stopped)
        #expect(alerts.Banner(in: stopped, at: Fixtures.now) == .carStopped(id: Fixtures.citraID, name: "Citra"))
    }

    @Test func AFormationAlertComesBeforeAStoppedCar() {
        var alerts = AlertsAfterDrivingThenStopping()
        var state = State(citra: .stopped)
        var other = Fixtures.Car(id: UUID(), name: "Dewi")
        other.alert = .offRoute
        state.participants.append(other)
        _ = alerts.Update(state)

        #expect(alerts.Banner(in: state, at: Fixtures.now) == .otherCar(id: other.id, name: "Dewi", alert: .offRoute))
    }
}
