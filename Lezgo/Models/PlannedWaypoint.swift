//
//  PlannedWaypoint.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// A waypoint picked in the planner, before it belongs to a trip.
struct PlannedWaypoint: Hashable {
    var kind: WaypointKind
    var name: String
    var coordinate: Coordinate
}

extension PlannedWaypoint {
    /// The start of a route changed on the road: the leader's position, named "Current Location".
    static func CurrentLocation(at coordinate: Coordinate) -> PlannedWaypoint {
        PlannedWaypoint(kind: .start, name: String(localized: .waypointCurrentLocation), coordinate: coordinate)
    }
}
