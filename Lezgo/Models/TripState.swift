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
}
