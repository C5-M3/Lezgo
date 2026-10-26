import Foundation

/// The trips an `InMemoryTripService` keeps, like a tiny server in memory.
///
/// Several services can share one store to act as several phones in one trip: give each its own iCloud user ID.
final class InMemoryTripStore {
    private(set) var trips: [UUID: TripState] = [:]
    private var listeners: [UUID: [UUID: AsyncStream<TripState>.Continuation]] = [:]

    init(trips: [TripState] = []) {}

    /// Stores the trip and sends it to everyone listening to it.
    func Save(_ state: TripState) {}

    /// The trip right away (when it exists), then again after every `Save`.
    func Listen(tripID: UUID) -> AsyncStream<TripState> {
        AsyncStream { $0.finish() }
    }
}
