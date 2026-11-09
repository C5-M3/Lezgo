//
//  FormationAlertDetector.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import CoreLocation

/// Decides a member's formation alert from each new trip state (`specs/UserStories.md` → US-06, "Formation alerts").
///
/// Off route, past the destination and ahead of the leader must last 5 seconds, so a GPS jump of a few seconds gives
/// no alert, but a wrong turn shows within seconds, as in Apple Maps. Time is read from the car's own `lastSeenAt`, so
/// a slow network does not stretch or shorten the wait.
struct FormationAlertDetector {
    /// Further than this from the route counts as off route.
    static let offRouteDistance: CLLocationDistance = 50
    /// Further than this past the next unvisited checkpoint counts as passing it.
    static let passedCheckpointDistance: CLLocationDistance = 200
    /// Further than this ahead of the leader, along the route, counts as ahead of the leader.
    static let aheadOfLeaderDistance: CLLocationDistance = 100
    /// Further than this past the end of the route counts as passing the destination; closer is parking.
    static let passedDestinationDistance: CLLocationDistance = 100
    /// How long off route, past the destination or ahead of the leader must last before the alert shows.
    static let holdTime: TimeInterval = 5

    /// When the car last went off the route, while it still has no alert for it.
    private var offRouteSince: Date?
    /// When the car last went too far ahead of the leader.
    private var aheadOfLeaderSince: Date?

    /// The alert of `participantID` in this state. Only one shows at a time: passed destination, off route, passed
    /// checkpoint, then ahead of the leader. The leader never has one.
    mutating func Update(_ state: TripState, for participantID: UUID) -> FormationAlert {
        guard let car = state.participants.first(where: { $0.id == participantID }),
              car.IsLeader(in: state.trip) == false,
              let coordinate = car.coordinate,
              let position = RoutePosition.Locate(coordinate, on: Polyline(of: state)) else {
            offRouteSince = nil
            aheadOfLeaderSince = nil
            return .none
        }
        // Past the destination is off the end of the route too; one wait covers both, as only one shows.
        let isOffRoute = HasLasted(
            position.distanceFromRoute > Self.offRouteDistance && IsOnShortcut(car, at: coordinate, in: state) == false,
            since: &offRouteSince,
            at: car.lastSeenAt
        )
        let isAheadOfLeader = HasLasted(
            IsAheadOfLeader(position, in: state, at: car.lastSeenAt),
            since: &aheadOfLeaderSince,
            at: car.lastSeenAt
        )
        if isOffRoute, HasPassedDestination(position, in: state) { return .passedDestination }
        if isOffRoute { return .offRoute }
        if HasPassedNextCheckpoint(position, in: state) { return .passedCheckpoint }
        if isAheadOfLeader { return .aheadOfLeader }
        return .none
    }

    /// The group's road: the leader's footprint, then the route ahead of the leader (see `TripState.groupPath`). A
    /// member behind the leader is measured against the road the leader actually took, not only the route ahead.
    private func Polyline(of state: TripState) -> [Coordinate] {
        state.groupPath
    }

    /// A member driving the shorter road their phone gave them has not left the route. Such a road starts on the
    /// group's road; a way back after a wrong turn starts where the car already was, off it.
    private func IsOnShortcut(_ car: Participant, at coordinate: Coordinate, in state: TripState) -> Bool {
        guard let start = car.wayBack.first,
              let startPosition = RoutePosition.Locate(start, on: Polyline(of: state)),
              startPosition.distanceFromRoute <= Self.offRouteDistance,
              let position = RoutePosition.Locate(coordinate, on: car.wayBack) else { return false }
        return position.distanceFromRoute <= Self.offRouteDistance
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

    /// Every checkpoint is visited and the car's nearest point on the road is its end, more than 100 m behind it.
    private func HasPassedDestination(_ position: RoutePosition, in state: TripState) -> Bool {
        let path = Polyline(of: state)
        guard state.nextCheckpoint == nil, let end = path.last,
              let endPosition = RoutePosition.Locate(end, on: path) else { return false }
        return position.distanceAlongRoute >= endPosition.distanceAlongRoute - 1
            && position.distanceFromRoute > Self.passedDestinationDistance
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
