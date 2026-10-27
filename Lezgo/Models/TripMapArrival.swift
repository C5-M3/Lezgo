import Foundation

/// Who has arrived at the destination (`specs/UserStories.md` → US-07, "Arrive").
///
/// A car has arrived within 20 m of the destination. Offline members count as not arrived, members without a
/// position yet count as not arrived, and members who left are no longer in the trip, so they are not counted.
struct TripMapArrival: Hashable {
    /// The arrival radius around the destination, in metres.
    static let radius: Double = 20

    var hasArrived: Bool
    var everyoneHasArrived: Bool

    static func Check(_ snapshot: TripMapSnapshot, at date: Date) -> TripMapArrival {
        TripMapArrival(hasArrived: false, everyoneHasArrived: false)
    }
}
