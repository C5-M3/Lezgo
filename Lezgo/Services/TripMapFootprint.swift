//
//  TripMapFootprint.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import CoreLocation
import Observation

/// The leader's footprint on this phone (`specs/UserStories.md` → US-06, "Footprint").
///
/// - On the leader's phone it records where the leader drives and saves it every few seconds, so the members behind
///   can follow the road the leader really took, also after a reroute.
/// - On a member's phone it guides along that road: the line ahead and the next turn follow the footprint to the
///   leader, and after a wrong turn it finds a way back to the footprint.
@Observable
final class TripMapFootprint {
    /// How often the leader's phone saves the footprint, in seconds of driving.
    static let saveInterval: TimeInterval = 5
    /// A member further than this from the group's road has left it.
    static let offPathDistance: CLLocationDistance = 50
    /// How long a member must be off the road before a way back is asked for, so a GPS jump asks for nothing.
    static let holdTime: TimeInterval = 5
    /// How long to wait before asking again after a way back failed or was left too.
    static let retryInterval: TimeInterval = 10
    /// A bend in the footprint sharper than this, in degrees, is a turn. Higher than for MapKit's roads, because GPS
    /// points wobble.
    static let turnThresholdDegrees = 40.0

    /// The leader's own footprint, fresher than the copy in the trip, which is a few seconds old.
    private(set) var trail = LeaderTrail()
    /// The road back to the group's road for a member who left it, or `nil` while they are on it.
    private(set) var wayBack: [Coordinate]?

    /// Counts the points added, so the trail is saved only when it grew, also once it is full.
    private var addedCount = 0
    private var savedCount = 0
    private var savedAt: Date?
    private var isSaving = false
    private var offPathSince: Date?
    private var askedAt: Date?
    private var isAsking = false

    private let tripID: UUID
    private let myParticipantID: UUID
    private let tripService: any TripService
    /// Finds the way back; `nil` in previews and the simulated drive.
    private let directionsService: (any DirectionsService)?

    init(
        tripID: UUID,
        myParticipantID: UUID,
        tripService: any TripService,
        directionsService: (any DirectionsService)?
    ) {
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.tripService = tripService
        self.directionsService = directionsService
    }

    // MARK: Leader

    /// Adds the leader's position, and saves the footprint when it grew and the last save is 5 seconds old. A failed
    /// save is tried again with the next position. Does nothing on a member's phone or outside the drive.
    func Record(_ reading: LocationReading, in state: TripState) async {
        guard state.trip.leaderParticipantID == myParticipantID, state.trip.status == .inTrip else { return }
        // After the app restarts, or a handover, carry on from the footprint the group already has.
        if trail.points.isEmpty, state.trail.isEmpty == false {
            trail = LeaderTrail(points: state.trail)
        }
        if trail.Append(reading.coordinate) { addedCount += 1 }
        guard addedCount != savedCount, isSaving == false,
              savedAt.map({ reading.recordedAt.timeIntervalSince($0) >= Self.saveInterval }) ?? true else { return }
        isSaving = true
        defer { isSaving = false }
        let count = addedCount
        guard (try? await tripService.SaveTrail(trail.points, tripID: tripID, by: myParticipantID)) != nil else {
            return
        }
        savedCount = count
        savedAt = reading.recordedAt
    }

    // MARK: Member

    /// The road ahead of a member: back to the group's road if they left it, then along the footprint to the leader
    /// and on along the route.
    func RouteAhead(from coordinate: Coordinate, in state: TripState) -> [Coordinate] {
        guard let wayBack, let rejoin = wayBack.last else {
            return RoutePosition.RouteAhead(of: coordinate, on: state.groupPath)
        }
        return RoutePosition.RouteAhead(of: coordinate, on: wayBack)
            + RoutePosition.RouteAhead(of: rejoin, on: state.groupPath).dropFirst()
    }

    /// Once this member has been off the group's road for 5 seconds, asks for a way back to the nearest point on it,
    /// and again when they leave that way too. Clears it once they are back on the road.
    func FindWayBack(in state: TripState) async {
        guard let directionsService,
              let me = state.participants.first(where: { $0.id == myParticipantID }),
              me.IsLeader(in: state.trip) == false,
              let coordinate = me.coordinate,
              let position = RoutePosition.Locate(coordinate, on: state.groupPath) else {
            offPathSince = nil
            wayBack = nil
            return
        }
        guard position.distanceFromRoute > Self.offPathDistance else {
            offPathSince = nil
            wayBack = nil
            return
        }
        let since = offPathSince ?? me.lastSeenAt
        offPathSince = since
        guard me.lastSeenAt.timeIntervalSince(since) >= Self.holdTime, IsOffWayBack(coordinate) else { return }
        guard isAsking == false,
              askedAt.map({ me.lastSeenAt.timeIntervalSince($0) >= Self.retryInterval }) ?? true,
              let rejoin = RoutePosition.RouteAhead(of: coordinate, on: state.groupPath).first else { return }
        isAsking = true
        defer { isAsking = false }
        askedAt = me.lastSeenAt
        // On failure the last way back, if any, stays: an old way is more use to a driver than none.
        if let path = try? await directionsService.DrivingPath(through: [coordinate, rejoin]) {
            wayBack = path
        }
    }

    /// The next turn along the line this member's map draws, while it follows the footprint or a way back. MapKit
    /// knows nothing about the road the leader took, so its own turn would point somewhere else. The time and
    /// distance left stay MapKit's. `nil` when MapKit's guidance fits: on the route ahead of the leader.
    func Guidance(
        adjusting guidance: TripMapGuidance,
        from coordinate: Coordinate,
        in state: TripState
    ) -> TripMapGuidance? {
        guard IsFollowingTheFootprint(coordinate, in: state) else { return nil }
        let path = RouteAhead(from: coordinate, in: state)
        let lengths = PathTurns.LengthsAlong(path)
        var adjusted = guidance
        let direction = { (index: Int) in
            PathTurns.Direction(in: path, lengths: lengths, at: index, threshold: Self.turnThresholdDegrees)
        }
        // A bend right at the car is the one it is driving through.
        let turn = path.indices.first { lengths[$0] > 5 && direction($0) != .straight }
        guard let turn else {
            adjusted.direction = .straight
            adjusted.instruction = String(localized: .tripMapFootprintFollow)
            adjusted.distanceToTurn = Measurement(value: lengths.last ?? 0, unit: .meters)
            return adjusted
        }
        adjusted.direction = direction(turn)
        adjusted.instruction = String(localized: Instruction(for: adjusted.direction))
        adjusted.distanceToTurn = Measurement(value: lengths[turn], unit: .meters)
        return adjusted
    }

    // MARK: Helpers

    /// Whether the member is on a way back, or behind the leader on the footprint.
    private func IsFollowingTheFootprint(_ coordinate: Coordinate, in state: TripState) -> Bool {
        if wayBack != nil { return true }
        guard state.trail.isEmpty == false,
              let leaderCoordinate = state.leader?.coordinate,
              let me = RoutePosition.Locate(coordinate, on: state.groupPath),
              let leader = RoutePosition.Locate(leaderCoordinate, on: state.groupPath) else { return false }
        return me.distanceAlongRoute < leader.distanceAlongRoute
    }

    /// `true` without a way back, or once the member has left it too.
    private func IsOffWayBack(_ coordinate: Coordinate) -> Bool {
        guard let wayBack, let position = RoutePosition.Locate(coordinate, on: wayBack) else { return true }
        return position.distanceFromRoute > Self.offPathDistance
    }

    private func Instruction(for direction: TripMapGuidance.TurnDirection) -> LocalizedStringResource {
        switch direction {
        case .left: .tripMapFootprintTurnLeft
        case .right: .tripMapFootprintTurnRight
        case .uTurn: .tripMapFootprintUTurn
        case .straight, .roundabout: .tripMapFootprintFollow
        }
    }
}
