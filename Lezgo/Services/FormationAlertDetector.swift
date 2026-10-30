//
//  FormationAlertDetector.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import CoreLocation

/// Decides a member's formation alert from each new trip state (`specs/UserStories.md` → US-06, "Formation alerts").
///
/// Off route and ahead of the leader must last 15 seconds, so a GPS jump of a few seconds gives no alert. Time is
/// read from the car's own `lastSeenAt`, so a slow network does not stretch or shorten the wait.
struct FormationAlertDetector {
    /// Further than this from the route counts as off route.
    static let offRouteDistance: CLLocationDistance = 100
    /// Further than this past the next unvisited checkpoint counts as passing it.
    static let passedCheckpointDistance: CLLocationDistance = 200
    /// Further than this ahead of the leader, along the route, counts as ahead of the leader.
    static let aheadOfLeaderDistance: CLLocationDistance = 200
    /// How long off route or ahead of the leader must last before the alert shows.
    static let holdTime: TimeInterval = 15

    /// When the car last went off the route, while it still has no alert for it.
    private var offRouteSince: Date?
    /// When the car last went too far ahead of the leader.
    private var aheadOfLeaderSince: Date?

    /// The alert of `participantID` in this state. Only one shows at a time: off route, then passed checkpoint, then
    /// ahead of the leader. The leader never has one.
    mutating func Update(_ state: TripState, for participantID: UUID) -> FormationAlert {
        guard let car = state.participants.first(where: { $0.id == participantID }),
              car.IsLeader(in: state.trip) == false,
              let coordinate = car.coordinate,
              let position = RoutePosition.Locate(coordinate, on: Polyline(of: state)) else {
            offRouteSince = nil
            aheadOfLeaderSince = nil
            return .none
        }
        let isOffRoute = HasLasted(
            position.distanceFromRoute > Self.offRouteDistance,
            since: &offRouteSince,
            at: car.lastSeenAt
        )
        let isAheadOfLeader = HasLasted(
            IsAheadOfLeader(position, in: state, at: car.lastSeenAt),
            since: &aheadOfLeaderSince,
            at: car.lastSeenAt
        )
        if isOffRoute { return .offRoute }
        if HasPassedNextCheckpoint(position, in: state) { return .passedCheckpoint }
        if isAheadOfLeader { return .aheadOfLeader }
        return .none
    }

    /// The road path; before a route exists, the straight line through the waypoints, like the map draws it.
    private func Polyline(of state: TripState) -> [Coordinate] {
        state.route?.polyline ?? state.waypoints.map(\.coordinate)
    }

    /// Whether `condition` has held for `holdTime`, keeping in `since` when it started.
    private func HasLasted(_ condition: Bool, since: inout Date?, at date: Date) -> Bool {
        guard condition else {
            since = nil
            return false
        }
        let start = since ?? date
        since = start
        return date.timeIntervalSince(start) >= Self.holdTime
    }

    private func HasPassedNextCheckpoint(_ position: RoutePosition, in state: TripState) -> Bool {
        guard let checkpoint = state.nextCheckpoint,
              let checkpointPosition = RoutePosition.Locate(checkpoint.coordinate, on: Polyline(of: state)) else {
            return false
        }
        return position.distanceAlongRoute - checkpointPosition.distanceAlongRoute > Self.passedCheckpointDistance
    }

    /// An offline leader pauses this alert: their last position says nothing about where they are now.
    private func IsAheadOfLeader(_ position: RoutePosition, in state: TripState, at date: Date) -> Bool {
        guard let leader = state.leader,
              leader.IsOnline(at: date),
              let leaderCoordinate = leader.coordinate,
              let leaderPosition = RoutePosition.Locate(leaderCoordinate, on: Polyline(of: state)) else {
            return false
        }
        return position.distanceAlongRoute - leaderPosition.distanceAlongRoute > Self.aheadOfLeaderDistance
    }
}
