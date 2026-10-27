import Foundation

/// Feeds the trip map from the shared `TripService`, turning each `TripState` into a `TripMapSnapshot`.
///
/// The trip map keeps its own `TripMap…` value types (built before the shared models existed); this adapter is the
/// one place that converts between them.
struct TripServiceMapAdapter: TripMapService {
    let tripService: any TripService
    /// The participant who uses this phone.
    let myParticipantID: UUID

    func TripUpdates(tripID: UUID) -> AsyncStream<TripMapSnapshot> {
        let states = tripService.TripUpdates(tripID: tripID)
        let myParticipantID = myParticipantID
        return AsyncStream { continuation in
            let task = Task {
                for await state in states {
                    continuation.yield(Self.MakeSnapshot(from: state, myParticipantID: myParticipantID))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The map's view of one trip state. Cars without a position yet are left out.
    static func MakeSnapshot(from state: TripState, myParticipantID: UUID) -> TripMapSnapshot {
        let polyline = state.route?.polyline ?? state.waypoints.map(\.coordinate)
        return TripMapSnapshot(
            tripID: state.trip.id,
            leaderParticipantID: state.trip.leaderParticipantID,
            myParticipantID: myParticipantID,
            currentWaypointIndex: state.trip.currentWaypointIndex,
            routeVersion: state.trip.routeVersion,
            waypoints: state.waypoints.map { MakeWaypoint($0) },
            cars: state.participants.compactMap { MakeCar($0) },
            memberIDs: state.participants.map(\.id),
            route: polyline.map { MakeCoordinate($0) }
        )
    }

    private static func MakeWaypoint(_ waypoint: Waypoint) -> TripMapWaypoint {
        TripMapWaypoint(
            id: waypoint.id,
            orderIndex: waypoint.orderIndex,
            kind: MakeKind(waypoint.kind),
            name: waypoint.name,
            coordinate: MakeCoordinate(waypoint.coordinate)
        )
    }

    private static func MakeKind(_ kind: WaypointKind) -> TripMapWaypointKind {
        switch kind {
        case .start: .start
        case .checkpoint: .checkpoint
        case .destination: .destination
        }
    }

    private static func MakeCar(_ participant: Participant) -> TripMapCar? {
        guard let coordinate = participant.coordinate else { return nil }
        return TripMapCar(
            id: participant.id,
            displayName: participant.displayName,
            carDescription: participant.carDescription,
            coordinate: MakeCoordinate(coordinate),
            speedKmh: participant.speedKmh,
            motionState: participant.motionState == .driving ? .driving : .stopped,
            lastSeenAt: participant.lastSeenAt
        )
    }

    private static func MakeCoordinate(_ coordinate: Coordinate) -> TripMapCoordinate {
        TripMapCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
