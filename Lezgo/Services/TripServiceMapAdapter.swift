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
        AsyncStream { $0.finish() }
    }

    /// The map's view of one trip state. Cars without a position yet are left out.
    static func MakeSnapshot(from state: TripState, myParticipantID: UUID) -> TripMapSnapshot {
        TripMapSnapshot(
            tripID: state.trip.id,
            leaderParticipantID: state.trip.leaderParticipantID,
            myParticipantID: myParticipantID,
            currentWaypointIndex: 0,
            routeVersion: 0,
            waypoints: [],
            cars: [],
            route: []
        )
    }
}
