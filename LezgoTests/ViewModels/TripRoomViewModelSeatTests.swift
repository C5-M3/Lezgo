//
//  TripRoomViewModelSeatTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 16/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The Trip Room when another phone of the same iCloud account takes this phone's place (ADR 0031).
@MainActor
struct TripRoomViewModelSeatTests {
    private let store = InMemoryTripStore()
    private let gps = MockLocationProvider()

    private func MakePhone() -> InMemoryTripService {
        InMemoryTripService(store: store, userRecordID: "_agus0001")
    }

    private func WaitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where condition() == false {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func RoomTellsThePersonWhenAnotherPhoneTakesTheirPlace() async throws {
        let first = MakePhone()
        let second = MakePhone()
        let session = try await first.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let storage = FakeActiveTripStorage(initial: ActiveTripSummary.From(session: session))
        let sharer = LocationSharer(
            tripService: first,
            locationProvider: gps,
            tripID: session.state.trip.id,
            participantID: session.myParticipantID
        )
        let viewModel = TripRoomViewModel(
            tripService: first,
            tripID: session.state.trip.id,
            myParticipantID: session.myParticipantID,
            initialState: session.state,
            activeTripStorage: storage,
            locationSharer: sharer
        )
        let listening = Task { await viewModel.Listen() }
        try await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.wasTakenOver == false)

        _ = try await second.JoinTrip(roomCode: session.state.trip.roomCode, profile: nil)
        try await WaitUntil { viewModel.wasTakenOver }
        listening.cancel()

        #expect(viewModel.wasTakenOver)
        #expect(storage.LoadActiveTrip() == nil)
        #expect(sharer.isStopped)
    }

    @Test func RoomKeepsWorkingWhenNobodyTakesThePlace() async throws {
        let first = MakePhone()
        let session = try await first.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let viewModel = TripRoomViewModel(
            tripService: first,
            tripID: session.state.trip.id,
            myParticipantID: session.myParticipantID,
            initialState: session.state,
            activeTripStorage: FakeActiveTripStorage(initial: ActiveTripSummary.From(session: session))
        )

        let listening = Task { await viewModel.Listen() }
        try await Task.sleep(for: .milliseconds(150))
        listening.cancel()

        #expect(viewModel.wasTakenOver == false)
    }
}
