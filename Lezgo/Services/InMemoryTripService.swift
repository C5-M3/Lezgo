import Foundation

/// A complete `TripService` that keeps trips in an `InMemoryTripStore` instead of iCloud (ADR 0017).
///
/// Previews, `DebugScreen`, unit tests and the app use it until `LiveTripService` lands. It follows the same rules
/// as the live service, so a screen that works with it works with iCloud. It cannot sync between phones.
final class InMemoryTripService: TripService {
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

    func CreateTrip(plan: TripPlan, profile: ParticipantProfile?) async throws -> TripSession {
        throw TripServiceError.notFound
    }
    func JoinTrip(roomCode: String, profile: ParticipantProfile?) async throws -> TripSession {
        throw TripServiceError.notFound
    }
    func FetchTrip(tripID: UUID) async throws -> TripState { throw TripServiceError.notFound }
    func TripUpdates(tripID: UUID) -> AsyncStream<TripState> { AsyncStream { $0.finish() } }
    func StartTrip(tripID: UUID, by leaderID: UUID) async throws {}
    func RemoveParticipants(_ participantIDs: [UUID], tripID: UUID, by leaderID: UUID) async throws {}
    func SetLeader(_ newLeaderID: UUID, tripID: UUID, replacing expectedLeaderID: UUID) async throws {}
    func ExitTrip(tripID: UUID, participantID: UUID) async throws {}
    func EndTrip(tripID: UUID, by leaderID: UUID) async throws {}
    func UpdateLocation(_ update: LocationUpdate, participantID: UUID, tripID: UUID) async throws {}
    func SetAlert(_ alert: FormationAlert, participantID: UUID, tripID: UUID) async throws {}
    func AdvanceCheckpoint(to waypointIndex: Int, tripID: UUID, by leaderID: UUID) async throws {}
    func SaveRoute(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws {}
    func StartNewDestination(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws {}
    func UpdateProfile(_ profile: ParticipantProfile, participantID: UUID, tripID: UUID) async throws {}
}
