//
//  TripPlan.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// A route from the planner (Set Route): the waypoints in order and the road path through them.
///
/// Used to create a trip, to change its route on the road (reroute, Edit Route) and for New Destination.
struct TripPlan: Hashable {
    /// In driving order: one start point, zero or more checkpoints, one destination.
    var waypoints: [PlannedWaypoint]
    var polyline: [Coordinate]

    /// A plan needs a start point first, a destination last, and only checkpoints in between.
    var isValid: Bool {
        let kinds = waypoints.map(\.kind)
        return kinds.count >= 2
            && kinds.first == .start
            && kinds.last == .destination
            && kinds.dropFirst().dropLast().allSatisfy { $0 == .checkpoint }
    }

    /// The plan's waypoints as they belong to a trip, numbered in driving order from 0.
    func MakeWaypoints(tripID: UUID) -> [Waypoint] {
        waypoints.enumerated().map { index, planned in
            Waypoint(
                id: UUID(),
                tripID: tripID,
                orderIndex: index,
                kind: planned.kind,
                name: planned.name,
                coordinate: planned.coordinate
            )
        }
    }
}
