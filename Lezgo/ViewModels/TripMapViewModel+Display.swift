//
//  TripMapViewModel+Display.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 29/10/26.
//

import Foundation

// What the map reads straight from the trip state. It lives in its own file so `TripMapViewModel.swift` stays under
// SwiftLint's 400-line limit while everything that changes the trip stays private there.
extension TripMapViewModel {
    var waypoints: [Waypoint] {
        state?.waypoints.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }

    /// The road path; before a route exists, the straight line through the waypoints.
    var route: [Coordinate] {
        state?.route?.polyline ?? waypoints.map(\.coordinate)
    }

    var destinationName: String? {
        state?.destination?.name
    }

    var isLeader: Bool {
        state?.trip.leaderParticipantID == myParticipantID
    }

    var myCoordinate: Coordinate? {
        state?.participants.first { $0.id == myParticipantID }?.coordinate
    }

    /// `true` until the first trip update arrives.
    var isLoading: Bool {
        state == nil
    }

    /// Whether the leader has already moved the trip past this waypoint.
    func IsVisited(_ waypoint: Waypoint) -> Bool {
        guard let state else { return false }
        return waypoint.IsVisited(currentWaypointIndex: state.trip.currentWaypointIndex)
    }
}
