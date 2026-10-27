import Foundation

/// Everything the trip map needs at one moment: the trip, its route, its waypoints and every car.
///
/// This is the hand-over point between the trip map and the rest of the app. Today it comes from
/// `SimulatedTripMapService`; once live trip updates (#83) land, an adapter builds it from the shared models.
struct TripMapSnapshot: Hashable {
    var tripID: UUID
    var leaderParticipantID: UUID
    /// The participant who uses this phone. It is not stored on the server; the phone knows it from joining.
    var myParticipantID: UUID
    var currentWaypointIndex: Int
    var routeVersion: Int
    var waypoints: [TripMapWaypoint]
    var cars: [TripMapCar]
    /// Everyone in the trip, including members whose phone has not sent a position yet (so they have no car).
    var memberIDs: [UUID]
    /// The road path from the start point through every checkpoint to the destination.
    var route: [TripMapCoordinate]
}
