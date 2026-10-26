import CloudKit
import Foundation

/// The `TripService` that syncs trips between phones through the CloudKit public database (ADR 0014).
final class LiveTripService: TripService {
    private let database: any CloudDatabase
    private let clock: () -> Date
    private let pollInterval: Duration
    private let makeRoomCode: () -> String

    init(
        database: any CloudDatabase,
        clock: @escaping () -> Date = { .now },
        pollInterval: Duration = .seconds(1),
        makeRoomCode: @escaping () -> String = { (0..<6).map { _ in String(Int.random(in: 0...9)) }.joined() }
    ) {
        self.database = database
        self.clock = clock
        self.pollInterval = pollInterval
        self.makeRoomCode = makeRoomCode
    }

    func CreateTrip(plan: TripPlan, profile: ParticipantProfile?) async throws -> TripSession {
        throw TripServiceError.notAllowed
    }
    func JoinTrip(roomCode: String, profile: ParticipantProfile?) async throws -> TripSession {
        throw TripServiceError.notAllowed
    }
    func FetchTrip(tripID: UUID) async throws -> TripState { throw TripServiceError.notAllowed }
    func TripUpdates(tripID: UUID) -> AsyncStream<TripState> { AsyncStream { $0.finish() } }
    func StartTrip(tripID: UUID, by leaderID: UUID) async throws { throw TripServiceError.notAllowed }
    func RemoveParticipants(_ participantIDs: [UUID], tripID: UUID, by leaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }
    func SetLeader(_ newLeaderID: UUID, tripID: UUID, replacing expectedLeaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }
    func ExitTrip(tripID: UUID, participantID: UUID) async throws { throw TripServiceError.notAllowed }
    func EndTrip(tripID: UUID, by leaderID: UUID) async throws { throw TripServiceError.notAllowed }
    func UpdateLocation(_ update: LocationUpdate, participantID: UUID, tripID: UUID) async throws {
        throw TripServiceError.notAllowed
    }
    func SetAlert(_ alert: FormationAlert, participantID: UUID, tripID: UUID) async throws {
        throw TripServiceError.notAllowed
    }
    func AdvanceCheckpoint(to waypointIndex: Int, tripID: UUID, by leaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }
    func SaveRoute(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws { throw TripServiceError.notAllowed }
    func StartNewDestination(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }
    func UpdateProfile(_ profile: ParticipantProfile, participantID: UUID, tripID: UUID) async throws {
        throw TripServiceError.notAllowed
    }
}
