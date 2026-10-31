//
//  TripMapReroute.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import CoreLocation

/// Reroutes the group when the leader leaves the route (`specs/UserStories.md` → US-06, "Route changes").
///
/// The leader's phone checks every trip update. Once the leader is more than 50 m off the route for 5 seconds, it
/// finds a new road path from the leader through the unvisited checkpoints to the destination and saves it as the
/// next route version. Every phone picks it up with its next update. Time is read from the leader's own `lastSeenAt`.
///
/// The limits are tighter than a member's off-route alert (100 m for 15 seconds), as Apple Maps reroutes within a
/// few seconds of a missed turn; 5 seconds still outlasts the GPS jumps of a few seconds that should not reroute.
///
/// Each route version is rerouted once. On failure (no network, no road found) the old route stays and the next try
/// waits 10 seconds.
///
/// While the leader has Edit Route open the reroute pauses, and a request already on its way is dropped, so it never
/// replaces the route the leader chose by hand.
final class TripMapReroute {
    /// How far from the route the leader must be before a reroute.
    static let offRouteDistance: CLLocationDistance = 50
    /// How long the leader must stay that far off before a reroute.
    static let holdTime: TimeInterval = 5
    /// How long to wait before trying again after a failed reroute.
    static let retryInterval: TimeInterval = 10

    private let tripID: UUID
    private let tripService: any TripService
    private let directionsService: any DirectionsService

    /// The route version the leader was last measured against.
    private var routeVersion: Int?
    /// When the leader last went off the route.
    private var offRouteSince: Date?
    /// `true` once this route version was rerouted, until the request fails.
    private var hasRequested = false
    /// No new request before this time, after a failure.
    private var retryAt: Date?
    /// `true` while the leader changes the route by hand.
    private var isPaused = false
    /// Counts the pauses, so a request that was on its way when one began is not saved.
    private var pauseCount = 0

    init(tripID: UUID, tripService: any TripService, directionsService: any DirectionsService) {
        self.tripID = tripID
        self.tripService = tripService
        self.directionsService = directionsService
    }

    /// Checks each state in order, until the stream finishes or the task is cancelled. Does nothing on a member's
    /// phone.
    func Run(_ states: AsyncStream<TripState>, myParticipantID: UUID) async {
        for await state in states {
            await Update(state, myParticipantID: myParticipantID)
        }
    }

    /// Edit Route opened: no reroute until `Resume()`.
    func Pause() {
        isPaused = true
        pauseCount += 1
        offRouteSince = nil
    }

    /// Edit Route closed. A saved route is a new route version, so the wait starts again either way.
    func Resume() {
        isPaused = false
    }

    /// Checks the new state and reroutes when it is time.
    private func Update(_ state: TripState, myParticipantID: UUID) async {
        guard let leader = state.leader, leader.id == myParticipantID, let coordinate = leader.coordinate else {
            Reset()
            return
        }
        guard isPaused == false else { return }
        guard let waypoints = WaypointsIfDue(state, leaderCoordinate: coordinate, at: leader.lastSeenAt) else { return }
        let pausesBefore = pauseCount
        do {
            let path = try await directionsService.DrivingPath(through: waypoints.map(\.coordinate))
            guard pauseCount == pausesBefore else {
                hasRequested = false
                return
            }
            let plan = TripPlan(waypoints: waypoints, polyline: path)
            try await tripService.SaveRoute(plan, tripID: tripID, by: myParticipantID)
        } catch {
            hasRequested = false
            retryAt = leader.lastSeenAt.addingTimeInterval(Self.retryInterval)
        }
    }

    /// The waypoints of the new route when the leader has been off the route long enough, or `nil`.
    private func WaypointsIfDue(_ state: TripState, leaderCoordinate: Coordinate, at date: Date) -> [PlannedWaypoint]? {
        // A new route starts at the leader's position, so the wait starts again on it.
        if routeVersion != state.trip.routeVersion {
            routeVersion = state.trip.routeVersion
            offRouteSince = nil
            hasRequested = false
        }
        guard IsOffRoute(leaderCoordinate, in: state) else {
            offRouteSince = nil
            retryAt = nil
            return nil
        }
        let since = offRouteSince ?? date
        offRouteSince = since
        guard date.timeIntervalSince(since) >= Self.holdTime,
              hasRequested == false,
              retryAt.map({ date >= $0 }) ?? true,
              let waypoints = state.RemainingWaypoints(from: .CurrentLocation(at: leaderCoordinate)) else { return nil }
        hasRequested = true
        return waypoints
    }

    /// This phone is not the leader (any more): the next drive starts fresh.
    private func Reset() {
        routeVersion = nil
        offRouteSince = nil
        hasRequested = false
        retryAt = nil
    }

    private func IsOffRoute(_ coordinate: Coordinate, in state: TripState) -> Bool {
        // Before a route exists, the straight line through the waypoints, like the map draws it.
        let polyline = state.route?.polyline ?? state.waypoints.map(\.coordinate)
        guard let position = RoutePosition.Locate(coordinate, on: polyline) else { return false }
        return position.distanceFromRoute > Self.offRouteDistance
    }
}
