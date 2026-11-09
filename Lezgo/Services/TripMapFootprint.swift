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
///   leader, and after a wrong turn it finds a way back to the footprint. When the leader drove a loop, it finds a
///   shortcut past it, so the member is not sent round it too.
@Observable
final class TripMapFootprint {
    /// How often the leader's phone saves the footprint, in seconds of driving.
    static let saveInterval: TimeInterval = 5
    /// A member further than this from the group's road has left it.
    static let offPathDistance: CLLocationDistance = 50
    /// How long a member must be off the road before a way back is asked for, so a GPS jump asks for nothing.
    static let holdTime: TimeInterval = 5
    /// How long off the road before the turn card says "Rerouting…", so a GPS jump does not flash it.
    static let noticeDelay: TimeInterval = 2
    /// The way back joins the road at least this far beyond where the member left it.
    static let rejoinAhead: CLLocationDistance = 50
    /// A shortcut is looked for while the footprint ahead to the leader is this many times the straight distance.
    static let loopRatio = 1.5
    /// No shortcut is looked for while the leader is closer than this in a straight line.
    static let shortcutMinimumDistance: CLLocationDistance = 200
    /// How often a member behind a loop checks for a shortcut, in seconds of driving.
    static let shortcutCheckInterval: TimeInterval = 15
    /// A shortcut is taken only when it is at least this much shorter than the footprint: about 30 seconds in town,
    /// so the line does not switch back and forth between two roads of about the same length.
    static let shortcutSaving: CLLocationDistance = 250
    /// How long to wait before asking again after a way back failed or was left too.
    static let retryInterval: TimeInterval = 10
    /// A bend in the footprint sharper than this, in degrees, is a turn. Higher than for MapKit's roads, because GPS
    /// points wobble.
    static let turnThresholdDegrees = 40.0

    /// The leader's own footprint, fresher than the copy in the trip, which is a few seconds old.
    private(set) var trail = LeaderTrail()
    /// The road back to the group's road for a member who left it, or `nil` while they are on it.
    private(set) var wayBack: [Coordinate]?
    /// `true` while a member is off the group's road and their way back is still on its way.
    private(set) var isFindingWayBack = false

    /// Counts the points added, so the trail is saved only when it grew, also once it is full.
    private var addedCount = 0
    private var savedCount = 0
    private var savedAt: Date?
    private var isSaving = false
    private var offPathSince: Date?
    private var askedAt: Date?
    /// How far along the group's road this member last was while on it.
    private var leftAt: CLLocationDistance?
    private var isAsking = false
    /// When this member last checked for a shortcut past a loop.
    private var shortcutCheckedAt: Date?
    /// The way back the group last heard about; `nil` before this phone saved one.
    private var sharedWayBack: [Coordinate]?
    private var isSharingWayBack = false

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

    /// Once this member has been off the group's road for 5 seconds, asks for a way back to it, and again when they
    /// leave that way too. On the road, looks for a shortcut past a loop the leader drove. A way back is kept while
    /// the member drives it, and goes once they reach its end, or keep to the road instead. From 2 seconds off the
    /// road until a way back arrives, `isFindingWayBack` is `true`, so the turn card says the app is working on it.
    func FindWayBack(in state: TripState) async {
        await UpdateWayBack(in: state)
        await ShareWayBack(in: state)
    }

    /// The trip with this member's own way back on their car, which the trip only carries once it has been shared and
    /// read back, so this phone's alert knows about a shortcut at once.
    func WithMyWayBack(_ state: TripState) -> TripState {
        guard let wayBack, let index = state.participants.firstIndex(where: { $0.id == myParticipantID }) else {
            return state
        }
        var state = state
        state.participants[index].wayBack = wayBack
        return state
    }

    private func UpdateWayBack(in state: TripState) async {
        guard let directionsService,
              let me = state.participants.first(where: { $0.id == myParticipantID }),
              me.IsLeader(in: state.trip) == false,
              let coordinate = me.coordinate,
              let position = RoutePosition.Locate(coordinate, on: state.groupPath) else {
            leftAt = nil
            Reset()
            return
        }
        if let wayBack, IsDriving(wayBack, at: coordinate) {
            isFindingWayBack = false
            return
        }
        let planner = TripMapWayBackPlanner(directionsService: directionsService)
        guard position.distanceFromRoute > Self.offPathDistance else {
            // On the road: remember how far along it this member got, so a way back never leads behind that.
            leftAt = position.distanceAlongRoute
            Reset()
            await FindShortcut(from: coordinate, me: me, at: position, in: state, planner: planner)
            return
        }
        let since = offPathSince ?? me.lastSeenAt
        offPathSince = since
        let offFor = me.lastSeenAt.timeIntervalSince(since)
        isFindingWayBack = offFor >= Self.noticeDelay
        guard offFor >= Self.holdTime, isAsking == false,
              askedAt.map({ me.lastSeenAt.timeIntervalSince($0) >= Self.retryInterval }) ?? true else { return }
        isAsking = true
        defer { isAsking = false }
        askedAt = me.lastSeenAt
        let earliest = (leftAt ?? 0) + Self.rejoinAhead
        // On failure the last way back, if any, stays: an old way is more use to a driver than none.
        if let choice = await planner.Best(from: coordinate, course: me.course, joiningAfter: earliest, in: state) {
            wayBack = choice.path
            isFindingWayBack = false
        }
    }

    /// While the footprint ahead to the leader is much longer than the straight distance to them, the leader drove a
    /// loop: every 15 seconds, looks for a road past it that is at least 250 m shorter.
    private func FindShortcut(
        from coordinate: Coordinate,
        me: Participant,
        at position: RoutePosition,
        in state: TripState,
        planner: TripMapWayBackPlanner
    ) async {
        guard isAsking == false,
              let leaderCoordinate = state.leader?.coordinate,
              let leader = RoutePosition.Locate(leaderCoordinate, on: state.groupPath) else { return }
        let footprintLeft = leader.distanceAlongRoute - position.distanceAlongRoute
        let straight = coordinate.Distance(to: leaderCoordinate)
        guard straight > Self.shortcutMinimumDistance, footprintLeft > straight * Self.loopRatio,
              shortcutCheckedAt.map({ me.lastSeenAt.timeIntervalSince($0) >= Self.shortcutCheckInterval }) ?? true
        else { return }
        isAsking = true
        defer { isAsking = false }
        shortcutCheckedAt = me.lastSeenAt
        let earliest = position.distanceAlongRoute + Self.rejoinAhead
        guard let choice = await planner.Best(from: coordinate, course: me.course, joiningAfter: earliest, in: state),
              choice.length + Self.shortcutSaving <= footprintLeft else { return }
        wayBack = choice.path
    }

    /// Tells the group when this member's way back changed, so the leader's map can show it. A failed save is tried
    /// again with the next update. Before the first save, the trip says what was last shared, so a way back left over
    /// from before the app restarted gets cleared.
    private func ShareWayBack(in state: TripState) async {
        guard let me = state.participants.first(where: { $0.id == myParticipantID }),
              me.IsLeader(in: state.trip) == false, isSharingWayBack == false else { return }
        let path = wayBack ?? []
        guard path != (sharedWayBack ?? me.wayBack) else { return }
        isSharingWayBack = true
        defer { isSharingWayBack = false }
        guard (try? await tripService.SetWayBack(path, participantID: myParticipantID, tripID: tripID)) != nil else {
            return
        }
        sharedWayBack = path
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

    /// Back on the road, or no longer a member on the road: nothing to find.
    private func Reset() {
        offPathSince = nil
        wayBack = nil
        isFindingWayBack = false
    }

    /// Whether the member is still on `wayBack` and has not reached its end yet.
    private func IsDriving(_ wayBack: [Coordinate], at coordinate: Coordinate) -> Bool {
        guard let end = wayBack.last, coordinate.Distance(to: end) > Self.offPathDistance,
              let position = RoutePosition.Locate(coordinate, on: wayBack) else { return false }
        return position.distanceFromRoute <= Self.offPathDistance
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
