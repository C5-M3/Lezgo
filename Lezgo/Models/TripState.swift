//
//  TripState.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// Everything a screen needs to know about one trip at one moment: the trip, its waypoints, its members and its
/// route. `TripService.TripUpdates(tripID:)` sends a new one whenever anything changes.
struct TripState: Hashable {
    var trip: Trip
    /// Sorted by `orderIndex`: start point first, destination last.
    var waypoints: [Waypoint]
    var participants: [Participant]
    /// `nil` only while a new trip is being created.
    var route: Route?

    var leader: Participant? {
        participants.first { $0.IsLeader(in: trip) }
    }

    var destination: Waypoint? {
        waypoints.last { $0.kind == .destination }
    }

    /// The first checkpoint the leader has not passed yet, or `nil` once every checkpoint is visited.
    var nextCheckpoint: Waypoint? {
        waypoints
            .filter { $0.kind == .checkpoint && $0.IsVisited(currentWaypointIndex: trip.currentWaypointIndex) == false }
            .min { $0.orderIndex < $1.orderIndex }
    }

    /// What is left of the route from `start`: the start, the unvisited checkpoints in order, then the destination.
    /// Used when the route changes on the road (reroute, Edit Route). `nil` without a destination.
    func RemainingWaypoints(from start: PlannedWaypoint) -> [PlannedWaypoint]? {
        guard let destination else { return nil }
        let checkpoints = waypoints
            .filter { $0.kind == .checkpoint && $0.IsVisited(currentWaypointIndex: trip.currentWaypointIndex) == false }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { PlannedWaypoint(kind: .checkpoint, name: $0.name, coordinate: $0.coordinate) }
        let end = PlannedWaypoint(kind: .destination, name: destination.name, coordinate: destination.coordinate)
        return [start] + checkpoints + [end]
    }
}
