//
//  TripMapFixtures.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation
@testable import Lezgo

/// The trip from `specs/UserStories.md` → US-06 as the trip map sees it: leader Agus, members Budi and Citra,
/// through checkpoint Ciputra World to Pakuwon mall.
enum TripMapFixtures {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let tripID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let agusID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1") ?? UUID()
    static let budiID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1") ?? UUID()
    static let citraID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1") ?? UUID()

    static let startPoint = Stop(0, .start, "Tunjungan Plaza", Coordinate(latitude: -7.2620, longitude: 112.7380))
    static let checkpoint = Stop(1, .checkpoint, "Ciputra World", Coordinate(latitude: -7.2923, longitude: 112.7190))
    static let destination = Stop(2, .destination, "Pakuwon mall", Coordinate(latitude: -7.2893, longitude: 112.6766))

    private static func Stop(_ index: Int, _ kind: WaypointKind, _ name: String, _ coordinate: Coordinate) -> Waypoint {
        Waypoint(id: UUID(), tripID: tripID, orderIndex: index, kind: kind, name: name, coordinate: coordinate)
    }

    /// A car (a participant with a position), seen `lastSeenSecondsAgo` before `now`.
    static func Car(
        id: UUID,
        name: String,
        latitude: Double = -7.2700,
        lastSeenSecondsAgo: Double = 1,
        motionState: MotionState = .driving
    ) -> Participant {
        Participant(
            id: id,
            tripID: tripID,
            userRecordID: "_\(name.lowercased())",
            displayName: name,
            carDescription: "Car of \(name)",
            coordinate: Coordinate(latitude: latitude, longitude: 112.7300),
            speedKmh: motionState == .driving ? 40 : 0,
            motionState: motionState,
            alert: .none,
            lastSeenAt: now.addingTimeInterval(-lastSeenSecondsAgo)
        )
    }

    /// A car `metres` north of the destination (Pakuwon mall), seen `lastSeenSecondsAgo` before `now`.
    static func CarNearDestination(
        id: UUID,
        name: String,
        metres: Double,
        lastSeenSecondsAgo: Double = 1
    ) -> Participant {
        var car = Car(id: id, name: name, lastSeenSecondsAgo: lastSeenSecondsAgo)
        car.coordinate = Coordinate(
            latitude: destination.coordinate.latitude + metres / 110_600,
            longitude: destination.coordinate.longitude
        )
        return car
    }

    /// The trip on the road. The waypoints are given out of order on purpose: the map must sort them.
    static func State(
        cars: [Participant]? = nil,
        status: TripStatus = .inTrip,
        waypoints: [Waypoint] = [destination, startPoint, checkpoint],
        currentWaypointIndex: Int = 1
    ) -> TripState {
        TripState(
            trip: Trip(
                id: tripID,
                roomCode: "897654",
                status: status,
                leaderParticipantID: agusID,
                currentWaypointIndex: currentWaypointIndex,
                routeVersion: 1,
                createdAt: now,
                startedAt: now,
                endedAt: nil
            ),
            waypoints: waypoints,
            participants: cars ?? [
                Car(id: agusID, name: "Agus", latitude: -7.2650),
                Car(id: budiID, name: "Budi", latitude: -7.2700),
                Car(id: citraID, name: "Citra", latitude: -7.2750)
            ],
            route: Route(
                id: UUID(),
                tripID: tripID,
                version: 1,
                polyline: [startPoint.coordinate, checkpoint.coordinate, destination.coordinate]
            )
        )
    }

    static func Guidance(minutesLeft: Int = 50) -> TripMapGuidance {
        TripMapGuidance(
            direction: .right,
            instruction: "Turn right",
            distanceToTurn: Measurement(value: 200, unit: .meters),
            timeLeft: .seconds(minutesLeft * 60)
        )
    }
}
