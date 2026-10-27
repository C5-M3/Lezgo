//
//  MockTripService.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation
@testable import Lezgo

/// A `TripService` whose live updates are a fixed list of states, sent at once and then finished.
///
/// "Exit Trip" and "End Trip" are recorded, and `failure` makes them throw. The trip map uses no other calls, so
/// they fail with `.notAllowed`; tests that need them use `InMemoryTripService`.
final class MockTripService: TripService {
    private let states: [TripState]
    private var continuation: AsyncStream<TripState>.Continuation?
    private(set) var requestedTripIDs: [UUID] = []
    private(set) var exitedParticipantIDs: [UUID] = []
    private(set) var endedByLeaderIDs: [UUID] = []
    /// When set, `ExitTrip` and `EndTrip` throw it.
    var failure: TripServiceError?
    /// Sent while `ExitTrip` or `EndTrip` is on its way, like an update from the cloud arriving before the request
    /// returns. When set, the stream stays open after `states`.
    var stateWhileLeaving: TripState?
    /// Runs while `ExitTrip` or `EndTrip` is on its way, after `stateWhileLeaving` was sent.
    var whileLeaving: (() async -> Void)?

    init(states: [TripState]) {
        self.states = states
    }

    func TripUpdates(tripID: UUID) -> AsyncStream<TripState> {
        requestedTripIDs.append(tripID)
        return AsyncStream { continuation in
            for state in states {
                continuation.yield(state)
            }
            if stateWhileLeaving == nil {
                continuation.finish()
            } else {
                self.continuation = continuation
            }
        }
    }

    func ExitTrip(tripID: UUID, participantID: UUID) async throws {
        if let failure { throw failure }
        await SendWhileLeaving()
        exitedParticipantIDs.append(participantID)
    }

    func EndTrip(tripID: UUID, by leaderID: UUID) async throws {
        if let failure { throw failure }
        await SendWhileLeaving()
        endedByLeaderIDs.append(leaderID)
    }

    private func SendWhileLeaving() async {
        if let stateWhileLeaving {
            continuation?.yield(stateWhileLeaving)
        }
        await whileLeaving?()
    }

    func CreateTrip(plan: TripPlan, profile: ParticipantProfile?) async throws -> TripSession {
        throw TripServiceError.notAllowed
    }

    func JoinTrip(roomCode: String, profile: ParticipantProfile?) async throws -> TripSession {
        throw TripServiceError.notAllowed
    }

    func FetchTrip(tripID: UUID) async throws -> TripState {
        guard let last = states.last else { throw TripServiceError.notFound }
        return last
    }

    func StartTrip(tripID: UUID, by leaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }

    func RemoveParticipants(_ participantIDs: [UUID], tripID: UUID, by leaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }

    func SetLeader(_ newLeaderID: UUID, tripID: UUID, replacing expectedLeaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }

    func UpdateLocation(_ update: LocationUpdate, participantID: UUID, tripID: UUID) async throws {
        throw TripServiceError.notAllowed
    }

    func SetAlert(_ alert: FormationAlert, participantID: UUID, tripID: UUID) async throws {
        throw TripServiceError.notAllowed
    }

    func AdvanceCheckpoint(to waypointIndex: Int, tripID: UUID, by leaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }

    func SaveRoute(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }

    func StartNewDestination(_ plan: TripPlan, tripID: UUID, by leaderID: UUID) async throws {
        throw TripServiceError.notAllowed
    }

    func UpdateProfile(_ profile: ParticipantProfile, participantID: UUID, tripID: UUID) async throws {
        throw TripServiceError.notAllowed
    }
}
