//
//  PlannedWaypoint.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

/// A waypoint picked in the planner, before it belongs to a trip.
struct PlannedWaypoint: Hashable {
    var kind: WaypointKind
    var name: String
    var coordinate: Coordinate
}
