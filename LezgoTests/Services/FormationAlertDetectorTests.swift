//
//  FormationAlertDetectorTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The US-06 formation alerts on a route near the equator: from the start east for about 1,113 m to the checkpoint,
/// then north to the destination. Leader Agus drives 100 m along it; member Budi is the phone under test.
struct FormationAlertDetectorTests {
    private typealias Fixtures = TripMapFixtures
    private static let metresPerDegree = 111_320.0
    /// How far along the route the checkpoint is, in metres.
    private static let checkpointAlongRoute = 0.01 * metresPerDegree

    private let start = Fixtures.now

    /// A point `metres` along the route and `sideways` metres to its left.
    private static func Along(_ metres: Double, sideways: Double = 0) -> Coordinate {
        if metres <= checkpointAlongRoute {
            return Coordinate(latitude: sideways / metresPerDegree, longitude: metres / metresPerDegree)
        }
        return Coordinate(
            latitude: (metres - checkpointAlongRoute) / metresPerDegree,
            longitude: 0.01 - sideways / metresPerDegree
        )
    }

    /// The trip when Budi's phone reads its position `seconds` after `start`.
    private func State(
        at seconds: TimeInterval,
        budi: Coordinate?,
        agus: Coordinate? = Self.Along(100),
        agusSeenSecondsEarlier: TimeInterval = 1,
        currentWaypointIndex: Int = 1
    ) -> TripState {
        let seenAt = start.addingTimeInterval(seconds)
        var budiCar = Fixtures.Car(id: Fixtures.budiID, name: "Budi")
        budiCar.coordinate = budi
        budiCar.lastSeenAt = seenAt
        var agusCar = Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        agusCar.coordinate = agus
        agusCar.lastSeenAt = seenAt.addingTimeInterval(-agusSeenSecondsEarlier)
        let waypoints = [
            Self.Stop(0, .start, "Tunjungan Plaza", at: 0),
            Self.Stop(1, .checkpoint, "Ciputra World", at: Self.checkpointAlongRoute),
            Self.Stop(2, .destination, "Pakuwon mall", at: 2 * Self.checkpointAlongRoute)
        ]
        var state = Fixtures.State(
            cars: [agusCar, budiCar],
            waypoints: waypoints,
            currentWaypointIndex: currentWaypointIndex
        )
        state.route?.polyline = waypoints.map { $0.coordinate }
        return state
    }

    private static func Stop(_ index: Int, _ kind: WaypointKind, _ name: String, at metres: Double) -> Waypoint {
        Waypoint(id: UUID(), tripID: Fixtures.tripID, orderIndex: index, kind: kind, name: name, coordinate: Along(metres))
    }

    /// Feeds Budi's readings in order and returns the alert after the last one.
    private func Alert(
        after readings: [TripState],
        for participantID: UUID = Fixtures.budiID
    ) -> FormationAlert {
        var detector = FormationAlertDetector()
        var alert = FormationAlert.none
        for state in readings {
            alert = detector.Update(state, for: participantID)
        }
        return alert
    }

    // MARK: On the route

    @Test func CarOnTheRouteHasNoAlert() {
        #expect(Alert(after: [State(at: 0, budi: Self.Along(50))]) == .none)
    }

    @Test func CarWithoutAPositionHasNoAlert() {
        #expect(Alert(after: [State(at: 0, budi: nil)]) == .none)
    }

    @Test func LeaderNeverHasAnAlert() {
        let readings = [0.0, 20].map { State(at: $0, budi: Self.Along(50), agus: Self.Along(300, sideways: 150)) }

        #expect(Alert(after: readings, for: Fixtures.agusID) == .none)
    }

    // MARK: Off route

    @Test(arguments: [(seconds: 0.0, alert: FormationAlert.none), (14, .none), (15, .offRoute), (40, .offRoute)])
    func CarOffTheRouteGetsTheAlertAfterFifteenSeconds(seconds: TimeInterval, alert: FormationAlert) {
        let readings = [0, seconds].map { State(at: $0, budi: Self.Along(50, sideways: 150)) }

        #expect(Alert(after: readings) == alert)
    }

    @Test func CarWithinHundredMetresOfTheRouteIsOnIt() {
        let readings = [0.0, 30].map { State(at: $0, budi: Self.Along(50, sideways: 90)) }

        #expect(Alert(after: readings) == .none)
    }

    @Test func GpsJumpGivesNoAlert() {
        let readings = [
            State(at: 0, budi: Self.Along(50, sideways: 150)),
            State(at: 3, budi: Self.Along(60, sideways: 150)),
            State(at: 4, budi: Self.Along(70)),
            State(at: 18, budi: Self.Along(80, sideways: 150))
        ]

        #expect(Alert(after: readings) == .none)
    }

    @Test func AlertEndsAsSoonAsTheCarIsBack() {
        let readings = [
            State(at: 0, budi: Self.Along(50, sideways: 150)),
            State(at: 15, budi: Self.Along(60, sideways: 150)),
            State(at: 16, budi: Self.Along(70))
        ]

        #expect(Alert(after: readings) == .none)
    }

    // MARK: Passed checkpoint

    @Test(arguments: [(pastBy: 150.0, alert: FormationAlert.none), (250, .passedCheckpoint)])
    func CarPastTheNextCheckpointGetsTheAlertAtOnce(pastBy: Double, alert: FormationAlert) {
        let state = State(at: 0, budi: Self.Along(Self.checkpointAlongRoute + pastBy), agus: Self.Along(1_100))

        #expect(Alert(after: [state]) == alert)
    }

    @Test func VisitedCheckpointGivesNoAlert() {
        let state = State(
            at: 0,
            budi: Self.Along(Self.checkpointAlongRoute + 250),
            agus: Self.Along(Self.checkpointAlongRoute + 100),
            currentWaypointIndex: 2
        )

        #expect(Alert(after: [state]) == .none)
    }

    // MARK: Ahead of leader

    @Test(arguments: [(seconds: 14.0, alert: FormationAlert.none), (15, .aheadOfLeader)])
    func CarFarAheadOfTheLeaderGetsTheAlertAfterFifteenSeconds(seconds: TimeInterval, alert: FormationAlert) {
        let readings = [0, seconds].map { State(at: $0, budi: Self.Along(350)) }

        #expect(Alert(after: readings) == alert)
    }

    @Test func CarALittleAheadOfTheLeaderHasNoAlert() {
        let readings = [0.0, 30].map { State(at: $0, budi: Self.Along(250)) }

        #expect(Alert(after: readings) == .none)
    }

    @Test func CarBehindTheLeaderHasNoAlert() {
        let readings = [0.0, 30].map { State(at: $0, budi: Self.Along(50), agus: Self.Along(600)) }

        #expect(Alert(after: readings) == .none)
    }

    @Test func OfflineLeaderPausesTheAheadAlert() {
        let readings = [0.0, 30].map { State(at: $0, budi: Self.Along(350), agusSeenSecondsEarlier: 180) }

        #expect(Alert(after: readings) == .none)
    }

    @Test func LeaderWithoutAPositionGivesNoAheadAlert() {
        let readings = [0.0, 30].map { State(at: $0, budi: Self.Along(350), agus: nil) }

        #expect(Alert(after: readings) == .none)
    }

    // MARK: One alert at a time

    @Test func OffRouteComesBeforeAheadOfLeader() {
        let readings = [0.0, 20].map { State(at: $0, budi: Self.Along(600, sideways: 150)) }

        #expect(Alert(after: readings) == .offRoute)
    }

    @Test func PassedCheckpointComesBeforeAheadOfLeader() {
        let readings = [0.0, 20].map { State(at: $0, budi: Self.Along(Self.checkpointAlongRoute + 250)) }

        #expect(Alert(after: readings) == .passedCheckpoint)
    }
}
