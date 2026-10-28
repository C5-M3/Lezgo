//
//  TripMapCheckpointProgress.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation

/// Decides when the leader's phone moves the trip past a checkpoint (`specs/UserStories.md` → US-06, "Map").
///
/// The checkpoint counts when the drive since the last update passes within 20 m of it: at 100 km/h a car moves
/// about 28 m between two updates, so both ends can be more than 20 m away ("Sync and timing"). Each checkpoint of
/// each route is asked for once; a new route (reroute or Edit Route) numbers its waypoints from 1 again.
struct TripMapCheckpointProgress {
    /// The leader's position at the previous update.
    private var previousCoordinate: Coordinate?
    /// The last move asked for, until it fails.
    private var requested: Request?

    /// The waypoint index to move the trip to after this leader update, or `nil` when there is nothing to ask.
    mutating func Update(_ state: TripState, leaderCoordinate: Coordinate) -> Int? {
        let drive = [previousCoordinate ?? leaderCoordinate, leaderCoordinate]
        previousCoordinate = leaderCoordinate
        guard let checkpoint = state.nextCheckpoint,
              let position = RoutePosition.Locate(checkpoint.coordinate, on: drive),
              position.distanceFromRoute <= TripMapArrival.radius else { return nil }
        let request = Request(routeVersion: state.trip.routeVersion, waypointIndex: checkpoint.orderIndex + 1)
        guard request != requested else { return nil }
        requested = request
        return request.waypointIndex
    }

    /// The move failed, so the next update asks again.
    mutating func Failed() {
        requested = nil
    }

    /// This phone is not the leader (any more): the next drive starts fresh.
    mutating func Reset() {
        previousCoordinate = nil
        requested = nil
    }

    private struct Request: Equatable {
        var routeVersion: Int
        var waypointIndex: Int
    }
}
