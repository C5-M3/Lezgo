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
    func LoadState(
        tripID: UUID,
        reusing previous: TripState? = nil,
        discoverMembers: Bool = true
    ) async throws -> TripState {
        // The trip and its members are independent requests, so they run at the same time.
        async let tripRecord = database.Fetch(TripRecordMapper.RecordID(tripID))
        async let members = Participants(of: tripID)
        let trip = try TripRecordMapper.MakeTrip(from: try await tripRecord)
        let participants = try await members
        if let previous, previous.trip.routeVersion == trip.routeVersion {
            return TripState(
                trip: trip,
                waypoints: previous.waypoints,
                participants: participants,
                route: previous.route
            )
        }
        async let waypointRecords = Children(of: tripID, type: TripRecordMapper.waypointType)
        async let routeRecords = Children(of: tripID, type: TripRecordMapper.routeType)
        let waypoints = try await waypointRecords
            .compactMap { try? TripRecordMapper.MakeWaypoint(from: $0) }
            .sorted { $0.orderIndex < $1.orderIndex }
        let route = try await routeRecords
            .compactMap { try? TripRecordMapper.MakeRoute(from: $0) }
            .first { $0.version == trip.routeVersion }
        return TripState(trip: trip, waypoints: waypoints, participants: participants, route: route)
    }

    /// The trip every `interval`, at a fixed rate, sent only when it changed. A failed fetch (no network) is retried
    /// at the next interval, so the stream keeps going while the phone is offline. Cancelling the listening task
    /// stops it.
    func Updates(tripID: UUID, every interval: Duration) -> AsyncStream<TripState> {
        AsyncStream { continuation in
            let task = Task {
                let clock = ContinuousClock()
                var deadline = clock.now
                var last: TripState?
                while Task.isCancelled == false {
                    if let state = try? await LoadState(tripID: tripID, reusing: last), state != last {
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
