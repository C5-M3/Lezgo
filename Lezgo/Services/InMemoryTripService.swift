import Foundation

/// A complete `TripService` that keeps trips in an `InMemoryTripStore` instead of iCloud (ADR 0017).
///
/// Previews, `DebugScreen`, unit tests and the app use it until `LiveTripService` lands. It follows the same rules
/// as the live service, so a screen that works with it works with iCloud. It cannot sync between phones.
final class InMemoryTripService: TripService {
    /// The service a screen gets from `@Environment(\.tripService)` when nothing above it set one, for example in
    /// a preview. One shared instance, so every read in the same preview sees the same trips.
    static let fallback = InMemoryTripService()

    /// When set, every call except `TripUpdates` throws this error, so previews and tests can show error states.
    var simulatedFailure: TripServiceError?

    private let store: InMemoryTripStore
    private let userRecordID: String
    private let clock: () -> Date
    private let makeRoomCode: () -> String

    /// - Parameters:
    ///   - store: the trips; share one store between services to act as several phones.
    ///   - userRecordID: the iCloud user of this phone.
    ///   - clock: the current time, so tests can fix it.
    ///   - makeRoomCode: makes a candidate room code; tests pass fixed codes to test collisions.
    init(
        store: InMemoryTripStore = InMemoryTripStore(),
        userRecordID: String = "_in-memory-user",
        clock: @escaping () -> Date = { .now },
        makeRoomCode: @escaping () -> String = { (0..<6).map { _ in String(Int.random(in: 0...9)) }.joined() }
    ) {
        self.store = store
        self.userRecordID = userRecordID
        self.clock = clock
        self.makeRoomCode = makeRoomCode
    }

    // MARK: Create, join and read

    func CreateTrip(plan: TripPlan, profile: ParticipantProfile?) async throws -> TripSession {
        try ThrowSimulatedFailure()
        try Validate(plan)
        let tripID = UUID()
        let leader = NewParticipant(tripID: tripID, profile: profile)
        let trip = Trip(
            id: tripID,
            roomCode: try UnusedRoomCode(),
            status: .lobby,
            leaderParticipantID: leader.id,
            currentWaypointIndex: 0,
            routeVersion: 1,
            createdAt: clock(),
            startedAt: nil,
            endedAt: nil
        )
        let state = TripState(
            trip: trip,
            waypoints: Waypoints(from: plan, tripID: tripID),
            participants: [leader],
            route: Route(id: UUID(), tripID: tripID, version: 1, polyline: plan.polyline)
        )
        store.Save(state)
        return TripSession(myParticipantID: leader.id, state: state)
    }

    func JoinTrip(roomCode: String, profile: ParticipantProfile?) async throws -> TripSession {
        try ThrowSimulatedFailure()
        let matches = store.trips.values.filter { $0.trip.roomCode == roomCode }
        guard matches.isEmpty == false else { throw TripServiceError.notFound }
        guard var state = matches.first(where: { IsOpen($0.trip.status) }) else { throw TripServiceError.tripEnded }

        if let existing = state.participants.first(where: { $0.userRecordID == userRecordID }) {
            return TripSession(myParticipantID: existing.id, state: state)
        }
        let member = NewParticipant(tripID: state.trip.id, profile: profile)
        state.participants.append(member)
        store.Save(state)
        return TripSession(myParticipantID: member.id, state: state)
    }

    func FetchTrip(tripID: UUID) async throws -> TripState {
        try ThrowSimulatedFailure()
        guard let state = store.trips[tripID] else { throw TripServiceError.notFound }
        return state
    }

    func TripUpdates(tripID: UUID) -> AsyncStream<TripState> {
        store.Listen(tripID: tripID)
    }

    // MARK: Leader actions in the Trip Room

    func StartTrip(tripID: UUID, by leaderID: UUID) async throws {
        try Change(tripID: tripID, by: leaderID) { state in
            guard state.trip.status == .lobby else { throw TripServiceError.notAllowed }
            state.trip.status = .inTrip
            state.trip.startedAt = clock()
            state.trip.currentWaypointIndex = 1
        }
    }

    func RemoveParticipants(_ participantIDs: [UUID], tripID: UUID, by leaderID: UUID) async throws {
        try Change(tripID: tripID, by: leaderID) { state in
            guard participantIDs.contains(leaderID) == false else { throw TripServiceError.notAllowed }
            state.participants.removeAll { participantIDs.contains($0.id) }
        }
    }

    func SetLeader(_ newLeaderID: UUID, tripID: UUID, replacing expectedLeaderID: UUID) async throws {
        try Change(tripID: tripID) { state in
            guard state.trip.leaderParticipantID == expectedLeaderID else { throw TripServiceError.conflict }
            guard state.participants.contains(where: { $0.id == newLeaderID }) else { throw TripServiceError.notFound }
            state.trip.leaderParticipantID = newLeaderID
        }
    }

    // MARK: Leave and end

    func ExitTrip(tripID: UUID, participantID: UUID) async throws {
        try Change(tripID: tripID) { state in
            guard state.trip.leaderParticipantID != participantID else { throw TripServiceError.notAllowed }
            state.participants.removeAll { $0.id == participantID }
        }
    }

    func EndTrip(tripID: UUID, by leaderID: UUID) async throws {
        try ThrowSimulatedFailure()
        guard let state = store.trips[tripID] else { throw TripServiceError.notFound }
        // Ending twice is harmless: a second phone may still show the button for a moment.
        guard IsOpen(state.trip.status) else { return }
        try Change(tripID: tripID, by: leaderID) { state in
            state.trip.status = state.trip.status == .lobby ? .cancelled : .ended
            state.trip.endedAt = clock()
        }
    }

    // MARK: On the road

    func UpdateLocation(_ update: LocationUpdate, participantID: UUID, tripID: UUID) async throws {
        try ChangeParticipant(participantID, tripID: tripID) { participant in
            participant.coordinate = update.coordinate
            participant.speedKmh = update.speedKmh
            participant.motionState = update.motionState
            participant.lastSeenAt = update.recordedAt
        }
    }

    func SetAlert(_ alert: FormationAlert, participantID: UUID, tripID: UUID) async throws {
        guard store.trips[tripID]?.trip.leaderParticipantID != participantID else { throw TripServiceError.notAllowed }
        try ChangeParticipant(participantID, tripID: tripID) { participant in
            participant.alert = alert
        }
    }

    func AdvanceCheckpoint(to waypointIndex: Int, tripID: UUID, by leaderID: UUID) async throws {
        try Change(tripID: tripID, by: leaderID) { state in
            guard state.trip.status == .inTrip else { throw TripServiceError.notAllowed }
            state.trip.currentWaypointIndex = max(state.trip.currentWaypointIndex, waypointIndex)
        }
    }

    func SaveRoute(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws {
        try Validate(plan)
        try Change(tripID: tripID, by: leaderID) { state in
            guard state.trip.status == .inTrip else { throw TripServiceError.notAllowed }
            ReplaceRoute(in: &state, with: plan)
            state.trip.currentWaypointIndex = 1
        }
    }

    func StartNewDestination(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws {
        try Validate(plan)
        try Change(tripID: tripID, by: leaderID) { state in
            guard state.trip.status == .inTrip else { throw TripServiceError.notAllowed }
            ReplaceRoute(in: &state, with: plan)
            state.trip.status = .lobby
            state.trip.currentWaypointIndex = 0
            state.trip.startedAt = nil
        }
    }

    // MARK: Profile

    func UpdateProfile(_ profile: ParticipantProfile, participantID: UUID, tripID: UUID) async throws {
        try ChangeParticipant(participantID, tripID: tripID) { participant in
            participant.displayName = profile.displayName
            participant.carDescription = profile.carDescription
        }
    }

    // MARK: Helpers

    private func ThrowSimulatedFailure() throws {
        if let simulatedFailure { throw simulatedFailure }
    }

    private func IsOpen(_ status: TripStatus) -> Bool {
        status == .lobby || status == .inTrip
    }

    /// Applies a change to an open trip and saves it, so every listener sees it.
    /// - Parameter leaderID: when given, the change is allowed only for the trip's leader.
    private func Change(tripID: UUID, by leaderID: UUID? = nil, _ change: (inout TripState) throws -> Void) throws {
        try ThrowSimulatedFailure()
        guard var state = store.trips[tripID] else { throw TripServiceError.notFound }
        guard IsOpen(state.trip.status) else { throw TripServiceError.tripEnded }
        if let leaderID, state.trip.leaderParticipantID != leaderID { throw TripServiceError.notAllowed }
        try change(&state)
        store.Save(state)
    }

    private func ChangeParticipant(
        _ participantID: UUID,
        tripID: UUID,
        _ change: (inout Participant) -> Void
    ) throws {
        try Change(tripID: tripID) { state in
            guard let index = state.participants.firstIndex(where: { $0.id == participantID }) else {
                throw TripServiceError.notFound
            }
            change(&state.participants[index])
        }
    }

    private func Validate(_ plan: TripPlan) throws {
        guard plan.isValid else { throw TripServiceError.notAllowed }
    }

    private func Waypoints(from plan: TripPlan, tripID: UUID) -> [Waypoint] {
        plan.waypoints.enumerated().map { index, planned in
            Waypoint(
                id: UUID(),
                tripID: tripID,
                orderIndex: index,
                kind: planned.kind,
                name: planned.name,
                coordinate: planned.coordinate
            )
        }
    }

    private func ReplaceRoute(in state: inout TripState, with plan: TripPlan) {
        let version = state.trip.routeVersion + 1
        state.trip.routeVersion = version
        state.waypoints = Waypoints(from: plan, tripID: state.trip.id)
        state.route = Route(id: UUID(), tripID: state.trip.id, version: version, polyline: plan.polyline)
    }

    private func NewParticipant(tripID: UUID, profile: ParticipantProfile?) -> Participant {
        let profile = profile ?? ParticipantProfile.Default(forUserRecordID: userRecordID)
        return Participant(
            id: UUID(),
            tripID: tripID,
            userRecordID: userRecordID,
            displayName: profile.displayName,
            carDescription: profile.carDescription,
            coordinate: nil,
            speedKmh: 0,
            motionState: .stopped,
            alert: .none,
            lastSeenAt: clock()
        )
    }

    /// A room code that no open trip uses. Ended trips may keep theirs: joining checks open trips first.
    private func UnusedRoomCode() throws -> String {
        let codesInUse = Set(store.trips.values.filter { IsOpen($0.trip.status) }.map(\.trip.roomCode))
        for _ in 0..<100 {
            let candidate = makeRoomCode()
            if codesInUse.contains(candidate) == false { return candidate }
        }
        throw TripServiceError.conflict
    }
}
