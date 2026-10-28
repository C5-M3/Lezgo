import Foundation

/// The live trip data the trip map listens to.
///
/// This protocol holds only what the trip map needs, so the screen does not depend on the whole `TripService`.
/// `TripServiceMapAdapter` implements it on top of the shared `TripService`; previews use
/// `SimulatedTripMapService`, and tests use `MockTripMapService`.
protocol TripMapService {
    /// A new snapshot whenever the trip, its route or any car changes, about once per second.
    /// The stream finishes when the trip is closed on this phone.
    func TripUpdates(tripID: UUID) -> AsyncStream<TripMapSnapshot>

    /// A member leaves the trip on the road ("Exit Trip").
    func ExitTrip(tripID: UUID, participantID: UUID) async throws

    /// The leader ends the trip for everyone ("End Trip").
    func EndTrip(tripID: UUID, by leaderID: UUID) async throws
}
