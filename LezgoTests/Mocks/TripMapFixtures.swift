import Foundation
@testable import Lezgo

/// The trip from `specs/UserStories.md` → US-06: leader Agus, members Budi and Citra, through checkpoint
/// Ciputra World to Pakuwon mall.
enum TripMapFixtures {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let tripID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let agusID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1") ?? UUID()
    static let budiID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1") ?? UUID()
    static let citraID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1") ?? UUID()

    static let startPoint = TripMapWaypoint(
        id: UUID(),
        orderIndex: 0,
        kind: .start,
        name: "Tunjungan Plaza",
        coordinate: TripMapCoordinate(latitude: -7.2620, longitude: 112.7380)
    )
    static let checkpoint = TripMapWaypoint(
        id: UUID(),
        orderIndex: 1,
        kind: .checkpoint,
        name: "Ciputra World",
        coordinate: TripMapCoordinate(latitude: -7.2923, longitude: 112.7190)
    )
    static let destination = TripMapWaypoint(
        id: UUID(),
        orderIndex: 2,
        kind: .destination,
        name: "Pakuwon mall",
        coordinate: TripMapCoordinate(latitude: -7.2893, longitude: 112.6766)
    )

    static func Car(
        id: UUID,
        name: String,
        latitude: Double = -7.2700,
        lastSeenSecondsAgo: Double = 1,
        motionState: TripMapMotionState = .driving
    ) -> TripMapCar {
        TripMapCar(
            id: id,
            displayName: name,
            carDescription: "Car of \(name)",
            coordinate: TripMapCoordinate(latitude: latitude, longitude: 112.7300),
            speedKmh: motionState == .driving ? 40 : 0,
            motionState: motionState,
            lastSeenAt: now.addingTimeInterval(-lastSeenSecondsAgo)
        )
    }

    static func Snapshot(
        me: UUID = budiID,
        cars: [TripMapCar]? = nil,
        memberIDs: [UUID]? = nil,
        waypoints: [TripMapWaypoint] = [destination, startPoint, checkpoint],
        currentWaypointIndex: Int = 1
    ) -> TripMapSnapshot {
        let cars = cars ?? [
            Car(id: agusID, name: "Agus", latitude: -7.2650),
            Car(id: budiID, name: "Budi", latitude: -7.2700),
            Car(id: citraID, name: "Citra", latitude: -7.2750)
        ]
        return TripMapSnapshot(
            tripID: tripID,
            leaderParticipantID: agusID,
            myParticipantID: me,
            currentWaypointIndex: currentWaypointIndex,
            routeVersion: 1,
            waypoints: waypoints,
            cars: cars,
            memberIDs: memberIDs ?? cars.map(\.id),
            route: [startPoint.coordinate, checkpoint.coordinate, destination.coordinate]
        )
    }

    /// A car `metres` north of the destination (Pakuwon mall), seen `lastSeenSecondsAgo` before `now`.
    static func CarNearDestination(
        id: UUID,
        name: String,
        metres: Double,
        lastSeenSecondsAgo: Double = 1
    ) -> TripMapCar {
        var car = Car(id: id, name: name, lastSeenSecondsAgo: lastSeenSecondsAgo)
        car.coordinate = TripMapCoordinate(
            latitude: destination.coordinate.latitude + metres / 110_600,
            longitude: destination.coordinate.longitude
        )
        return car
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
