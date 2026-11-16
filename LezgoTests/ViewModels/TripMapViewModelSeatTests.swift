//
//  TripMapViewModelSeatTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 16/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The trip map when another phone of the same iCloud account takes this phone's place (ADR 0031).
@MainActor
struct TripMapViewModelSeatTests {
    private let store = InMemoryTripStore()

    private func MakePhone() -> InMemoryTripService {
        InMemoryTripService(store: store, userRecordID: "_agus0001")
    }

    @Test(.timeLimit(.minutes(1)))
    func MapClosesAndStopsSharingWhenAnotherPhoneTakesThePlace() async throws {
        let first = MakePhone()
        let second = MakePhone()
        let session = try await first.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        // The map is for a trip on the road; in the lobby it would go back to the Trip Room.
        try await first.StartTrip(tripID: session.state.trip.id, by: session.myParticipantID)
        let storage = FakeActiveTripStorage(initial: ActiveTripSummary.From(session: session))
        let sharer = LocationSharer(
            tripService: first,
            locationProvider: MockLocationProvider(),
            tripID: session.state.trip.id,
            participantID: session.myParticipantID
        )
        let viewModel = TripMapViewModel(
            tripID: session.state.trip.id,
            myParticipantID: session.myParticipantID,
            tripService: first,
            navigator: MockTripMapNavigator(results: []),
            streetNameService: MockStreetNameService(),
            locationSharer: sharer,
            activeTripStorage: storage
        )
        let running = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.closeReason == nil)

        _ = try await second.JoinTrip(roomCode: session.state.trip.roomCode, profile: nil)
        while viewModel.closeReason == nil { try await Task.sleep(for: .milliseconds(10)) }
        running.cancel()

        #expect(viewModel.closeReason == .takenOver)
        #expect(storage.LoadActiveTrip() == nil)
        #expect(sharer.isStopped)
    }

    @Test func MapKeepsRunningWhenNobodyTakesThePlace() async throws {
        let first = MakePhone()
        let session = try await first.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        try await first.StartTrip(tripID: session.state.trip.id, by: session.myParticipantID)
        let viewModel = TripMapViewModel(
            tripID: session.state.trip.id,
            myParticipantID: session.myParticipantID,
            tripService: first,
            navigator: MockTripMapNavigator(results: []),
            streetNameService: MockStreetNameService()
        )

        let running = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(150))
        running.cancel()

        #expect(viewModel.closeReason == nil)
    }
}
