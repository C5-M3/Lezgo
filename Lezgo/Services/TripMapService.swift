import Foundation

/// The live trip data the trip map listens to.
///
/// This protocol holds only what the trip map needs, so the screen does not depend on the whole `TripService`.
/// When live trip updates (#83) land, `LiveTripService` conforms to it in one extension that turns the shared
/// models into a `TripMapSnapshot`. Until then the app uses `SimulatedTripMapService`, and tests use
/// `MockTripMapService`.
protocol TripMapService {
    /// A new snapshot whenever the trip, its route or any car changes, about once per second.
    /// The stream finishes when the trip is closed on this phone.
    func TripUpdates(tripID: UUID) -> AsyncStream<TripMapSnapshot>
}
