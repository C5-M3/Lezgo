//
//  TripRecordReader.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import CloudKit
import Foundation

/// Reads a trip and its child records from a `CloudDatabase` for `LiveTripService`.
///
/// Errors are CloudKit's own; `LiveTripService` turns them into `TripServiceError`. Child records the app cannot
/// read (for example from an older build) are skipped instead of failing the whole trip.
struct TripRecordReader {
    let database: any CloudDatabase

    /// The trip with its waypoints, members and current route. When `previous` has the same route version, its
    /// waypoints and route are reused, so a poll costs two requests (sent together) instead of four.
    /// - Parameter discoverMembers: `false` reads only the members in `previous`, by record ID. That is faster than
    ///   a query and always up to date, but it cannot see someone who just joined.
    /// - Parameter loadTrail: `false` keeps the leader's footprint from `previous`. It is the largest record and
    ///   changes only every few seconds, so polls read it less often.
    func LoadState(
        tripID: UUID,
        reusing previous: TripState? = nil,
        discoverMembers: Bool = true,
        loadTrail: Bool = true
    ) async throws -> TripState {
        // The trip, its members and the footprint are independent requests, so they run at the same time.
        async let tripRecord = database.Fetch(TripRecordMapper.RecordID(tripID))
        let known = discoverMembers ? nil : previous?.participants
        async let members = Members(of: tripID, known: known)
        async let footprint = Trail(of: tripID, loading: loadTrail, previous: previous)
        let trip = try TripRecordMapper.MakeTrip(from: try await tripRecord)
        let participants = try await members
        let trail = try await footprint
        // Reused only once the current route was read in full, so a read the query index was not ready for is
        // tried again on the next poll instead of being kept until the route changes again (#291).
        if let previous, previous.route?.version == trip.routeVersion {
            return TripState(
                trip: trip,
                waypoints: previous.waypoints,
                participants: participants,
                route: previous.route,
                trail: trail
            )
        }
        async let waypointRecords = Children(of: tripID, type: TripRecordMapper.waypointType)
        async let routeRecords = Children(of: tripID, type: TripRecordMapper.routeType)
        let routeRecord = try await routeRecords.first {
            (try? TripRecordMapper.MakeRoute(from: $0))?.version == trip.routeVersion
        }
        let route = routeRecord.flatMap { try? TripRecordMapper.MakeRoute(from: $0) }
        let waypoints = Self.CurrentWaypoints(in: try await waypointRecords, savedWith: routeRecord)
        if let previous, route == nil || Self.IsWholeRoute(waypoints) == false {
            // The query cannot see the new route yet: keep showing the one the group already has.
            return TripState(
                trip: trip,
                waypoints: previous.waypoints,
                participants: participants,
                route: previous.route,
                trail: trail
            )
        }
        return TripState(trip: trip, waypoints: waypoints, participants: participants, route: route, trail: trail)
    }

    /// The stops of the trip's current route, in driving order. A query can still return the stops of an older route
    /// (deleted, or never deleted because the query that looked for them could not see them yet), so only the stops
    /// the server saved together with the current route record are kept (#291). Saving a stop again, as a kept
    /// destination is, gives it a new modification time. A record without a time keeps its place: that is a record
    /// that never came from the server.
    private static func CurrentWaypoints(in records: [CKRecord], savedWith routeRecord: CKRecord?) -> [Waypoint] {
        let current = records.filter { record in
            guard let routeSavedAt = routeRecord?.modificationDate, let savedAt = record.modificationDate else {
                return true
            }
            return abs(savedAt.timeIntervalSince(routeSavedAt)) <= savedTogetherWithin
        }
        return current
            .compactMap { try? TripRecordMapper.MakeWaypoint(from: $0) }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// How far apart the server may stamp the records of one save. Routes change at least several seconds apart (a
    /// car must be off the route for 5 seconds before a reroute), so the stops of the route before are further away.
    private static let savedTogetherWithin: TimeInterval = 2

    /// Whether these are every stop of one route: numbered 0, 1, 2… from the start to the destination.
    private static func IsWholeRoute(_ waypoints: [Waypoint]) -> Bool {
        waypoints.count >= 2
            && waypoints.map(\.orderIndex) == Array(waypoints.indices)
            && waypoints.first?.kind == .start
            && waypoints.last?.kind == .destination
    }

    /// The leader's footprint, or the one in `previous` when this poll skips it. Empty before the leader saves one.
    private func Trail(of tripID: UUID, loading: Bool, previous: TripState?) async throws -> [Coordinate] {
        guard loading else { return previous?.trail ?? [] }
        let records = try await database.Fetch([TripRecordMapper.TrailRecordID(tripID)])
        return records.first.flatMap { try? TripRecordMapper.MakeTrail(from: $0) } ?? []
    }

    /// The trip every `interval`, at a fixed rate, sent only when it changed. A failed fetch (no network) is retried
    /// at the next interval, so the stream keeps going while the phone is offline. Cancelling the listening task
    /// stops it.
    ///
    /// Known members are read by record ID on every poll; the slower member query, which finds people who just
    /// joined, runs every `discoverMembersEvery` polls (#69). The leader's footprint is read every `loadTrailEvery`
    /// polls: the leader's phone saves it only every few seconds.
    func Updates(
        tripID: UUID,
        every interval: Duration,
        discoverMembersEvery: Int = 2,
        loadTrailEvery: Int = 3
    ) -> AsyncStream<TripState> {
        AsyncStream { continuation in
            let task = Task {
                let clock = ContinuousClock()
                var deadline = clock.now
                var last: TripState?
                var poll = 0
                while Task.isCancelled == false {
                    let discover = poll.isMultiple(of: max(discoverMembersEvery, 1))
                    let loadTrail = poll.isMultiple(of: max(loadTrailEvery, 1))
                    poll += 1
                    if let state = try? await LoadState(
                        tripID: tripID,
                        reusing: last,
                        discoverMembers: discover,
                        loadTrail: loadTrail
                    ), state != last {
                        continuation.yield(state)
                        last = state
                    }
                    // A slow fetch shortens the wait instead of adding to it.
                    deadline = max(deadline.advanced(by: interval), clock.now)
                    try? await Task.sleep(until: deadline, clock: clock)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The trip's members in the order they joined.
    func Participants(of tripID: UUID) async throws -> [Participant] {
        try await Children(of: tripID, type: TripRecordMapper.participantType)
            .sorted(by: JoinedBefore)
            .compactMap { try? TripRecordMapper.MakeParticipant(from: $0) }
    }

    /// The known members by record ID, or every member by query when `known` is `nil`.
    private func Members(of tripID: UUID, known: [Participant]?) async throws -> [Participant] {
        if let known {
            return try await KnownParticipants(known, of: tripID)
        }
        return try await Participants(of: tripID)
    }

    /// The members in `known` that still belong to the trip, read by record ID in one request, in the same order.
    /// A member who left is gone, and a stray record left by a removed member's last position has no trip.
    func KnownParticipants(_ known: [Participant], of tripID: UUID) async throws -> [Participant] {
        try await database.Fetch(known.map { TripRecordMapper.RecordID($0.id) })
            .compactMap { try? TripRecordMapper.MakeParticipant(from: $0) }
            .filter { $0.tripID == tripID }
    }

    /// Every record of this type that belongs to the trip.
    func Children(of tripID: UUID, type: String) async throws -> [CKRecord] {
        try await database.Query(recordType: type, matching: ["tripID": TripRecordMapper.TripReference(tripID)])
    }

    /// Whether an open trip already uses this room code. Ended trips may keep theirs.
    func IsRoomCodeInUse(_ roomCode: String) async throws -> Bool {
        try await database
            .Query(recordType: TripRecordMapper.tripType, matching: ["roomCode": roomCode])
            .compactMap { try? TripRecordMapper.MakeTrip(from: $0) }
            .contains { $0.status.isOpen }
    }

    /// The trip and its record, when it is still open.
    /// - Parameter leaderID: when given, throws `.notAllowed` unless this participant leads the trip.
    func OpenTrip(_ tripID: UUID, by leaderID: UUID? = nil) async throws -> (Trip, CKRecord) {
        let record = try await database.Fetch(TripRecordMapper.RecordID(tripID))
        let trip = try TripRecordMapper.MakeTrip(from: record)
        guard trip.status.isOpen else { throw TripServiceError.tripEnded }
        if let leaderID, trip.leaderParticipantID != leaderID { throw TripServiceError.notAllowed }
        return (trip, record)
    }

    /// Records sort by creation date, then name, so the order is stable even when two were created at once.
    private func JoinedBefore(_ first: CKRecord, _ second: CKRecord) -> Bool {
        let firstCreated = first.creationDate ?? .distantPast
        let secondCreated = second.creationDate ?? .distantPast
        guard firstCreated == secondCreated else { return firstCreated < secondCreated }
        return first.recordID.recordName < second.recordID.recordName
    }
}
