import Foundation

/// A start point, checkpoint or destination of a trip's route.
///
/// Order: the start point is `0`, checkpoints `1…n`, the destination `n + 1`.
struct Waypoint: Identifiable, Hashable, Codable {
    let id: UUID
    var tripID: UUID
    var orderIndex: Int
    var kind: WaypointKind
    var name: String
    var coordinate: Coordinate

    /// A waypoint is visited once the leader has moved the trip past it.
    func IsVisited(currentWaypointIndex: Int) -> Bool {
        false
    }
}
