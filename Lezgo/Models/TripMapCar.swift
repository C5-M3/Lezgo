import Foundation

/// One car (one participant, one phone) as the trip map shows it.
///
/// Mirrors the map fields of `Participant` in `specs/UserStories.md` → "Data model".
struct TripMapCar: Identifiable, Hashable {
    /// How long a car may go without sending a location before it counts as offline.
    static let offlineAfter: Duration = .seconds(120)

    let id: UUID
    var displayName: String
    var carDescription: String
    var coordinate: TripMapCoordinate
    var speedKmh: Double
    var motionState: TripMapMotionState
    var lastSeenAt: Date

    /// A car is online until its last location is older than 2 minutes; exactly 2 minutes is still online.
    func IsOnline(at date: Date) -> Bool {
        true
    }
}
