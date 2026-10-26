import Foundation

/// A start point, checkpoint or destination as the trip map shows it.
///
/// Mirrors `Waypoint` in `specs/UserStories.md` → "Data model": the start point has `orderIndex` 0,
/// checkpoints 1…n and the destination n + 1.
struct TripMapWaypoint: Identifiable, Hashable {
    let id: UUID
    var orderIndex: Int
    var kind: TripMapWaypointKind
    var name: String
    var coordinate: TripMapCoordinate

    /// A waypoint is visited once the leader has moved the trip past it.
    func IsVisited(currentWaypointIndex: Int) -> Bool {
        false
    }
}
