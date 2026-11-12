//
//  JoinTripIntentJoinTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 13/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// "Join a trip" from Siri joins right away, like "Enter" in the join dialog (`specs/UserStories.md` → US-08).
@MainActor
struct JoinTripIntentJoinTests {
    @Test func ExistingCodeJoinsAndSavesTheTrip() async throws {
        let service = InMemoryTripService()
        let created = try await service.CreateTrip(
            plan: TripPlanFixtures.tunjunganToPakuwon,
            profile: TripPlanFixtures.agusProfile
        )
        let storage = FakeActiveTripStorage()

        let outcome = await JoinTripIntent.Join(
            roomCode: created.state.trip.roomCode,
            tripService: service,
            storage: storage,
            profileStorage: FakeProfileStorage(TripPlanFixtures.budiProfile)
        )

        guard case .joined(let session) = outcome else {
            Issue.record("Expected to join, got \(outcome)")
            return
        }
        #expect(session.state.trip.id == created.state.trip.id)
        #expect(session.state.participants.contains { $0.id == session.myParticipantID })
        #expect(storage.storedSummary?.roomCode == created.state.trip.roomCode)
    }

    @Test func UnknownCodeSaysWhyAndJoinsNothing() async {
        let storage = FakeActiveTripStorage()

        let outcome = await JoinTripIntent.Join(
            roomCode: "111111",
            tripService: InMemoryTripService(),
            storage: storage,
            profileStorage: FakeProfileStorage()
        )

        #expect(outcome == .failed(String(localized: .tripServiceErrorNotFound)))
        #expect(storage.storedSummary == nil)
    }
}
