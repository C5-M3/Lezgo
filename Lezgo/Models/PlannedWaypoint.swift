/// A waypoint picked in the planner, before it belongs to a trip.
struct PlannedWaypoint: Hashable {
    var kind: WaypointKind
    var name: String
    var coordinate: Coordinate
}
