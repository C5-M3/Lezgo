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
    /// The road the leader has driven, oldest point first (see `LeaderTrail`); empty until the leader's phone saves it.
    var trail: [Coordinate] = []

    /// The road every member follows: the leader's footprint, then the leader, then the route ahead of the leader.
    /// After a reroute the route starts at the leader, so without the footprint every member still behind would be
    /// off it. Without a footprint yet, the route itself; before a route exists, the straight line through the
    /// waypoints, like the map draws it.
    var groupPath: [Coordinate] {
        let planned = route?.polyline ?? waypoints.map(\.coordinate)
        guard trail.isEmpty == false, let leaderCoordinate = leader?.coordinate else { return planned }
        return trail + [leaderCoordinate] + RoutePosition.RouteAhead(of: leaderCoordinate, on: planned)
    }

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

    /// The name the group sees for a car: the name its driver typed, otherwise "Leader" for the leader and "Car 2",
    /// "Car 3", … for the members in the order they joined (the leader counts as car 1). iOS does not tell apps the
    /// iCloud account's name, and the team chose not to ask for one.
    func DisplayName(of participant: Participant) -> String {
        guard participant.displayName.allSatisfy(\.isWhitespace) else { return participant.displayName }
        if participant.IsLeader(in: trip) {
            return String(localized: .participantLeaderName)
        }
        let members = participants.filter { $0.IsLeader(in: trip) == false }
        let number = (members.firstIndex { $0.id == participant.id } ?? members.count) + 2
        return String(localized: .participantCarName(number))
    }
}
