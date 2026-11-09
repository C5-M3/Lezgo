//
//  LiveTripService.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import CloudKit
import Foundation

/// The `TripService` that syncs trips between phones through the CloudKit public database (ADR 0014).
///
/// It follows the same rules as `InMemoryTripService`; the `TripService*Tests` suites run against both. Every
/// error reaches the caller as a `TripServiceError`.
final class LiveTripService: TripService {
    private let database: any CloudDatabase
    private let reader: TripRecordReader
    private let clock: () -> Date
    private let pollInterval: Duration
    private let makeRoomCode: () -> String
    private var userRecordName: String?

    /// - Parameters:
    ///   - database: the public database; `LiveCloudDatabase()` in the app, a fake in tests.
    ///   - clock: the current time, so tests can fix it.
    ///   - pollInterval: how often `TripUpdates` fetches the trip (1 second, "Sync and timing").
    ///   - makeRoomCode: makes a candidate room code; tests pass fixed codes to test collisions.
    init(
        database: any CloudDatabase,
        clock: @escaping () -> Date = { .now },
        pollInterval: Duration = .seconds(1),
        makeRoomCode: @escaping () -> String = { (0..<6).map { _ in String(Int.random(in: 0...9)) }.joined() }
    ) {
        self.database = database
        self.reader = TripRecordReader(database: database)
        self.clock = clock
        self.pollInterval = pollInterval
        self.makeRoomCode = makeRoomCode
    }

    // MARK: Create, join and read

    func CreateTrip(plan: TripPlan, profile: ParticipantProfile?) async throws -> TripSession {
        try await Run {
            guard plan.isValid else { throw TripServiceError.notAllowed }
            let tripID = UUID()
            let leader = Participant.Joining(
                tripID: tripID,
                userRecordID: try await UserRecordName(),
                profile: profile,
                isLeader: true,
                at: clock()
            )
            let trip = Trip(
                id: tripID,
                roomCode: try await UnusedRoomCode(),
                status: .lobby,
                leaderParticipantID: leader.id,
                currentWaypointIndex: 0,
                routeVersion: 1,
                createdAt: clock(),
                startedAt: nil,
                endedAt: nil
            )
            let waypoints = plan.MakeWaypoints(tripID: tripID)
            let route = Route(id: UUID(), tripID: tripID, version: 1, polyline: plan.polyline)
            let records = [TripRecordMapper.MakeRecord(trip)]
                + waypoints.map { TripRecordMapper.MakeRecord($0) }
                + [TripRecordMapper.MakeRecord(leader), TripRecordMapper.MakeRecord(route)]
            try await database.Save(records, savePolicy: .allKeys)
            let state = TripState(trip: trip, waypoints: waypoints, participants: [leader], route: route)
            return TripSession(myParticipantID: leader.id, state: state)
        }
    }

    func JoinTrip(roomCode: String, profile: ParticipantProfile?) async throws -> TripSession {
        try await Run {
            let me = try await UserRecordName()
            let trips = try await database
                .Query(recordType: TripRecordMapper.tripType, matching: ["roomCode": roomCode])
                .compactMap { try? TripRecordMapper.MakeTrip(from: $0) }
            guard trips.isEmpty == false else { throw TripServiceError.notFound }
            guard let trip = trips.first(where: { $0.status.isOpen }) else { throw TripServiceError.tripEnded }

            let existing = try await database.Query(
                recordType: TripRecordMapper.participantType,
                matching: ["tripID": TripRecordMapper.TripReference(trip.id), "userRecordID": me]
            )
            if let record = existing.first, let participant = try? TripRecordMapper.MakeParticipant(from: record) {
                return TripSession(myParticipantID: participant.id, state: try await reader.LoadState(tripID: trip.id))
            }
            let taken = try await Run { try await reader.LoadState(tripID: trip.id) }
            let member = Participant.Joining(
                tripID: trip.id, userRecordID: me, profile: profile.map { taken.WithoutTakenName($0) },
                isLeader: false, at: clock()
            )
            try await database.Save([TripRecordMapper.MakeRecord(member)], savePolicy: .allKeys)
            return TripSession(myParticipantID: member.id, state: try await reader.LoadState(tripID: trip.id))
        }
    }

    func FetchTrip(tripID: UUID) async throws -> TripState {
        try await Run { try await reader.LoadState(tripID: tripID) }
    }

    /// Fetches the trip every `pollInterval` and sends it when it changed (see `TripRecordReader.Updates`).
    func TripUpdates(tripID: UUID) -> AsyncStream<TripState> {
        reader.Updates(tripID: tripID, every: pollInterval)
    }

    // MARK: Leader actions in the Trip Room

    func StartTrip(tripID: UUID, by leaderID: UUID) async throws {
        try await ChangeTrip(tripID, by: leaderID) { trip in
            guard trip.status == .lobby else { throw TripServiceError.notAllowed }
            trip.status = .inTrip
            trip.startedAt = clock()
            trip.currentWaypointIndex = 1
        }
    }

    func RemoveParticipants(_ participantIDs: [UUID], tripID: UUID, by leaderID: UUID) async throws {
        try await Run {
            _ = try await reader.OpenTrip(tripID, by: leaderID)
            guard participantIDs.contains(leaderID) == false else { throw TripServiceError.notAllowed }
            let members = try await reader.Participants(of: tripID).map(\.id)
            let removed = participantIDs.filter(members.contains)
            try await database.Delete(removed.map { TripRecordMapper.RecordID($0) })
        }
    }

    /// A conditional save: the trip record is saved only if nobody changed it since it was fetched, so when two
    /// phones pick a new leader at once, the first wins and the second gets `.conflict`.
    func SetLeader(_ newLeaderID: UUID, tripID: UUID, replacing expectedLeaderID: UUID) async throws {
        try await Run {
            let (trip, record) = try await reader.OpenTrip(tripID)
            guard trip.leaderParticipantID == expectedLeaderID else { throw TripServiceError.conflict }
            guard try await reader.Participants(of: tripID).contains(where: { $0.id == newLeaderID }) else {
                throw TripServiceError.notFound
            }
            var changed = trip
            changed.leaderParticipantID = newLeaderID
            TripRecordMapper.Write(changed, into: record)
            try await database.Save([record], savePolicy: .ifServerRecordUnchanged)
            // The leader never has a formation alert, so one saved as a member is cleared. Only the alert key is
            // saved, so the new leader's latest location is not overwritten.
            let leaderRecord = CKRecord(
                recordType: TripRecordMapper.participantType,
                recordID: TripRecordMapper.RecordID(newLeaderID)
            )
            leaderRecord["alert"] = FormationAlert.none.rawValue
            try await database.Save([leaderRecord], savePolicy: .changedKeys)
        }
    }

    // MARK: Leave and end

    func ExitTrip(tripID: UUID, participantID: UUID) async throws {
        try await Run {
            let (trip, _) = try await reader.OpenTrip(tripID)
            guard trip.leaderParticipantID != participantID else { throw TripServiceError.notAllowed }
            try await database.Delete([TripRecordMapper.RecordID(participantID)])
        }
    }

    func EndTrip(tripID: UUID, by leaderID: UUID) async throws {
        try await Run {
            let record = try await database.Fetch(TripRecordMapper.RecordID(tripID))
            var trip = try TripRecordMapper.MakeTrip(from: record)
            // Ending twice is harmless: a second phone may still show the button for a moment.
            guard trip.status.isOpen else { return }
            guard trip.leaderParticipantID == leaderID else { throw TripServiceError.notAllowed }
            trip.status = trip.status == .lobby ? .cancelled : .ended
            trip.endedAt = clock()
            TripRecordMapper.Write(trip, into: record)
            try await database.Save([record], savePolicy: .changedKeys)
        }
    }

    // MARK: On the road

    /// One request per update: only the location fields are saved, without fetching the participant first. If the
    /// participant was removed a moment ago, the save makes a stray record without a trip, which no phone ever
    /// reads, so the member does not come back.
    func UpdateLocation(_ update: LocationUpdate, participantID: UUID, tripID: UUID) async throws {
        try await Run {
            let record = CKRecord(
                recordType: TripRecordMapper.participantType,
                recordID: TripRecordMapper.RecordID(participantID)
            )
            TripRecordMapper.WriteLocation(update, into: record)
            try await database.Save([record], savePolicy: .changedKeys)
        }
    }

    func SetAlert(_ alert: FormationAlert, participantID: UUID, tripID: UUID) async throws {
        try await Run {
            let (trip, _) = try await reader.OpenTrip(tripID)
            guard trip.leaderParticipantID != participantID else { throw TripServiceError.notAllowed }
        }
        try await ChangeParticipant(participantID, tripID: tripID) { participant in
            participant.alert = alert
        }
    }

    func AdvanceCheckpoint(to waypointIndex: Int, tripID: UUID, by leaderID: UUID) async throws {
        try await ChangeTrip(tripID, by: leaderID) { trip in
            guard trip.status == .inTrip else { throw TripServiceError.notAllowed }
            trip.currentWaypointIndex = max(trip.currentWaypointIndex, waypointIndex)
        }
    }

    func SaveRoute(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws {
        try await ReplaceRoute(
            tripID,
            with: plan,
            by: leaderID,
            allowing: [.lobby, .inTrip],
            keepsDestination: true
        ) { trip in
            // In the lobby nobody has left yet, so the first stop to reach stays the start.
            if trip.status == .inTrip { trip.currentWaypointIndex = 1 }
        }
    }

    func StartNewDestination(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws {
        try await ReplaceRoute(tripID, with: plan, by: leaderID) { trip in
            trip.status = .lobby
            trip.currentWaypointIndex = 0
            trip.startedAt = nil
        }
    }

    // MARK: Profile

    func UpdateProfile(_ profile: ParticipantProfile, participantID: UUID, tripID: UUID) async throws {
        try await EnsureNameIsFree(profile.displayName, in: tripID, excluding: participantID)
        try await ChangeParticipant(participantID, tripID: tripID) { participant in
            participant.displayName = profile.displayName
            participant.carDescription = profile.carDescription
            participant.avatar = profile.avatar ?? participant.avatar
        }
    }

    // MARK: Writing

    private func ChangeTrip(_ tripID: UUID, by leaderID: UUID, _ change: (inout Trip) throws -> Void) async throws {
        try await Run {
            let (trip, record) = try await reader.OpenTrip(tripID, by: leaderID)
            var changed = trip
            try change(&changed)
            TripRecordMapper.Write(changed, into: record)
            try await database.Save([record], savePolicy: .changedKeys)
        }
    }

    private func ChangeParticipant(
        _ participantID: UUID,
        tripID: UUID,
        _ change: (inout Participant) -> Void
    ) async throws {
        try await Run {
            let record = try await database.Fetch(TripRecordMapper.RecordID(participantID))
            var participant = try TripRecordMapper.MakeParticipant(from: record)
            guard participant.tripID == tripID else { throw TripServiceError.notFound }
            change(&participant)
            TripRecordMapper.Write(participant, into: record)
            try await database.Save([record], savePolicy: .changedKeys)
        }
    }

    // MARK: Helpers

    /// Runs one operation and turns any CloudKit or network error into a `TripServiceError`.
    private func Run<Result>(_ work: () async throws -> Result) async throws -> Result {
        do {
            return try await work()
        } catch {
            throw TripServiceError(cloudKitError: error)
        }
    }

    private func UserRecordName() async throws -> String {
        if let userRecordName { return userRecordName }
        let name = try await database.CurrentUserRecordName()
        userRecordName = name
        return name
    }

    /// A room code that no open trip uses. Ended trips may keep theirs: joining picks the open trip.
    private func UnusedRoomCode() async throws -> String {
        for _ in 0..<20 {
            let candidate = makeRoomCode()
            if try await reader.IsRoomCodeInUse(candidate) == false { return candidate }
        }
        throw TripServiceError.conflict
    }
}

// MARK: - Following the leader

extension LiveTripService {
    /// Replaces the footprint record. Only the leader writes it, so a plain overwrite cannot lose anyone's change.
    func SaveTrail(_ trail: [Coordinate], tripID: UUID, by leaderID: UUID) async throws {
        try await Run {
            _ = try await reader.OpenTrip(tripID, by: leaderID)
            let record = TripRecordMapper.MakeTrailRecord(trail, tripID: tripID)
            try await database.Save([record], savePolicy: .allKeys)
        }
    }

    func SetWayBack(_ wayBack: [Coordinate], participantID: UUID, tripID: UUID) async throws {
        try await Run {
            let (trip, _) = try await reader.OpenTrip(tripID)
            guard trip.leaderParticipantID != participantID else { throw TripServiceError.notAllowed }
        }
        try await ChangeParticipant(participantID, tripID: tripID) { participant in
            participant.wayBack = wayBack
        }
    }

    func MarkArrived(at destinationID: UUID, participantID: UUID, tripID: UUID) async throws {
        let state = try await FetchTrip(tripID: tripID)
        guard state.trip.status == .inTrip, state.destination?.id == destinationID else {
            throw TripServiceError.notAllowed
        }
        try await ChangeParticipant(participantID, tripID: tripID) { participant in
            participant.arrivedAtWaypointID = destinationID
        }
    }
}

// MARK: Names

extension LiveTripService {
    /// Throws `.nameAlreadyUsed` when another car in the trip has this name, so two cars never share one (US-04).
    /// CloudKit has no unique rule, so two phones saving the same name in the same second can still both pass.
    fileprivate func EnsureNameIsFree(
        _ name: String,
        in tripID: UUID,
        excluding participantID: UUID? = nil
    ) async throws {
        let state = try await Run { try await reader.LoadState(tripID: tripID) }
        if state.IsNameTaken(name, excluding: participantID) { throw TripServiceError.nameAlreadyUsed }
    }
}

// MARK: - Replacing the route

extension LiveTripService {
    /// Saves the new waypoints and route first and the trip last, so a phone never sees a route version without
    /// its route. The old waypoints and routes are deleted afterwards.
    /// - Parameter keepsDestination: a destination still in the same place keeps its record, and with it every
    ///   "I've Arrived" saved for it.
    private func ReplaceRoute(
        _ tripID: UUID,
        with plan: TripPlan,
        by leaderID: UUID,
        allowing allowedStatuses: [TripStatus] = [.inTrip],
        keepsDestination: Bool = false,
        _ change: (inout Trip) -> Void
    ) async throws {
        try await Run {
            guard plan.isValid else { throw TripServiceError.notAllowed }
            let (trip, record) = try await reader.OpenTrip(tripID, by: leaderID)
            guard allowedStatuses.contains(trip.status) else { throw TripServiceError.notAllowed }
            let oldWaypoints = try await reader.Children(of: tripID, type: TripRecordMapper.waypointType)
            let oldRoutes = try await reader.Children(of: tripID, type: TripRecordMapper.routeType)
            let oldDestination = keepsDestination
                ? try oldWaypoints.map(TripRecordMapper.MakeWaypoint).first { $0.kind == .destination }
                : nil

            var changed = trip
            changed.routeVersion += 1
            change(&changed)
            let waypoints = plan.MakeWaypoints(tripID: tripID, keeping: oldDestination)
            let keptRecordIDs = Set(waypoints.map { TripRecordMapper.RecordID($0.id) })
            let oldRecordIDs = (oldWaypoints + oldRoutes).map(\.recordID).filter { keptRecordIDs.contains($0) == false }
            let route = Route(id: UUID(), tripID: tripID, version: changed.routeVersion, polyline: plan.polyline)
            try await database.Save(
                waypoints.map { TripRecordMapper.MakeRecord($0) } + [TripRecordMapper.MakeRecord(route)],
                savePolicy: .allKeys
            )
            TripRecordMapper.Write(changed, into: record)
            try await database.Save([record], savePolicy: .changedKeys)
            try await database.Delete(oldRecordIDs)
        }
    }
}
