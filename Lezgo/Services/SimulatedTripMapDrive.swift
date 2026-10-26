#if DEBUG
import Foundation

/// A scripted drive through Surabaya for previews and the `-DebugScreen` simulator check.
///
/// It plays the US-06 trip from `specs/UserStories.md`: leader Agus, members Budi and Citra, from Tunjungan Plaza
/// through checkpoint Ciputra World to Pakuwon mall. Agus drives in front, Budi 250 m behind him, and Citra
/// stays offline at her last position. The route is a rough road path, good enough to see the map move.
///
/// Debug builds only: it is replaced by live trip data (#83) and the routing service (#72).
struct SimulatedTripMapDrive {
    static let tripID = UUID(uuidString: "5A1E0000-0000-0000-0000-000000000001") ?? UUID()
    static let agusID = UUID(uuidString: "5A1E0000-0000-0000-0000-0000000000A1") ?? UUID()
    static let budiID = UUID(uuidString: "5A1E0000-0000-0000-0000-0000000000B1") ?? UUID()
    static let citraID = UUID(uuidString: "5A1E0000-0000-0000-0000-0000000000C1") ?? UUID()

    /// About 40 km/h, one step per 1-second update.
    static let metresPerSecond = 11.0

    static let route: [TripMapCoordinate] = [
        TripMapCoordinate(latitude: -7.2622, longitude: 112.7387),
        TripMapCoordinate(latitude: -7.2651, longitude: 112.7378),
        TripMapCoordinate(latitude: -7.2702, longitude: 112.7358),
        TripMapCoordinate(latitude: -7.2760, longitude: 112.7335),
        TripMapCoordinate(latitude: -7.2795, longitude: 112.7300),
        TripMapCoordinate(latitude: -7.2840, longitude: 112.7262),
        TripMapCoordinate(latitude: -7.2893, longitude: 112.7218),
        TripMapCoordinate(latitude: -7.2923, longitude: 112.7190),
        TripMapCoordinate(latitude: -7.2919, longitude: 112.7120),
        TripMapCoordinate(latitude: -7.2905, longitude: 112.7030),
        TripMapCoordinate(latitude: -7.2898, longitude: 112.6935),
        TripMapCoordinate(latitude: -7.2890, longitude: 112.6850),
        TripMapCoordinate(latitude: -7.2893, longitude: 112.6766)
    ]

    /// Index in `route` of the checkpoint, Ciputra World.
    static let checkpointRouteIndex = 7

    static let waypoints: [TripMapWaypoint] = [
        TripMapWaypoint(
            id: UUID(uuidString: "5A1E0000-0000-0000-0000-0000000000F0") ?? UUID(),
            orderIndex: 0,
            kind: .start,
            name: "Tunjungan Plaza",
            coordinate: route[0]
        ),
        TripMapWaypoint(
            id: UUID(uuidString: "5A1E0000-0000-0000-0000-0000000000F1") ?? UUID(),
            orderIndex: 1,
            kind: .checkpoint,
            name: "Ciputra World",
            coordinate: route[checkpointRouteIndex]
        ),
        TripMapWaypoint(
            id: UUID(uuidString: "5A1E0000-0000-0000-0000-0000000000F2") ?? UUID(),
            orderIndex: 2,
            kind: .destination,
            name: "Pakuwon mall",
            coordinate: route[route.count - 1]
        )
    ]

    /// Total length of the route in metres.
    static let routeLength: Double = zip(route, route.dropFirst()).reduce(0) { $0 + $1.0.Distance(to: $1.1) }

    /// Distance along the route, in metres, from the start point to `route[index]`.
    static func DistanceAlongRoute(toRouteIndex index: Int) -> Double {
        zip(route.prefix(index + 1), route.prefix(index + 1).dropFirst()).reduce(0) { $0 + $1.0.Distance(to: $1.1) }
    }

    /// The point `distance` metres along the route, clamped to the start point and the destination.
    static func Coordinate(atDistance distance: Double) -> TripMapCoordinate {
        var remaining = max(distance, 0)
        for (from, to) in zip(route, route.dropFirst()) {
            let length = from.Distance(to: to)
            if remaining <= length, length > 0 {
                let fraction = remaining / length
                return TripMapCoordinate(
                    latitude: from.latitude + (to.latitude - from.latitude) * fraction,
                    longitude: from.longitude + (to.longitude - from.longitude) * fraction
                )
            }
            remaining -= length
        }
        return route[route.count - 1]
    }

    /// The trip after `elapsedSeconds` of driving, seen from the phone of `myParticipantID`.
    static func Snapshot(elapsedSeconds: Int, myParticipantID: UUID, now: Date) -> TripMapSnapshot {
        let agusDistance = 400 + Double(elapsedSeconds) * metresPerSecond
        let budiDistance = agusDistance - 250
        let leaderPassedCheckpoint = agusDistance >= DistanceAlongRoute(toRouteIndex: checkpointRouteIndex)
        let agusArrived = agusDistance >= routeLength

        return TripMapSnapshot(
            tripID: tripID,
            leaderParticipantID: agusID,
            myParticipantID: myParticipantID,
            currentWaypointIndex: leaderPassedCheckpoint ? 2 : 1,
            routeVersion: 1,
            waypoints: waypoints,
            cars: [
                TripMapCar(
                    id: agusID,
                    displayName: "Agus",
                    carDescription: "Black Avanza",
                    coordinate: Coordinate(atDistance: agusDistance),
                    speedKmh: agusArrived ? 0 : metresPerSecond * 3.6,
                    motionState: agusArrived ? .stopped : .driving,
                    lastSeenAt: now
                ),
                TripMapCar(
                    id: budiID,
                    displayName: "Budi",
                    carDescription: "White Brio",
                    coordinate: Coordinate(atDistance: budiDistance),
                    speedKmh: metresPerSecond * 3.6,
                    motionState: .driving,
                    lastSeenAt: now
                ),
                TripMapCar(
                    id: citraID,
                    displayName: "Citra",
                    carDescription: "Red Jazz",
                    coordinate: Coordinate(atDistance: 150),
                    speedKmh: 0,
                    motionState: .stopped,
                    lastSeenAt: now.addingTimeInterval(-180)
                )
            ],
            route: route
        )
    }
}
#endif
