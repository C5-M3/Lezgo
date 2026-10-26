/// A route from the planner (Set Route): the waypoints in order and the road path through them.
///
/// Used to create a trip, to change its route on the road (reroute, Edit Route) and for New Destination.
struct TripPlan: Hashable {
    /// In driving order: one start point, zero or more checkpoints, one destination.
    var waypoints: [PlannedWaypoint]
    var polyline: [Coordinate]
}
