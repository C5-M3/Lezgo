//
//  InMemoryTripServiceTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Rules only `InMemoryTripService` has. The shared rules are in the `TripService*Tests` suites.
struct InMemoryTripServiceTests {
    @Test func RoomCodeInUseIsNotGivenTwice() async throws {
        var codes = ["111111", "111111", "222222"]
        let makeRoomCode = { codes.removeFirst() }
        let store = InMemoryTripStore()
        let first = InMemoryTripService(store: store, userRecordID: "_one", makeRoomCode: makeRoomCode)
        let second = InMemoryTripService(store: store, userRecordID: "_two", makeRoomCode: makeRoomCode)

        let firstTrip = try await first.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let secondTrip = try await second.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        #expect(firstTrip.state.trip.roomCode == "111111")
        #expect(secondTrip.state.trip.roomCode == "222222")
    }

    @Test func SimulatedFailureIsThrown() async {
        let service = InMemoryTripService()
        service.simulatedFailure = .noNetwork

        await #expect(throws: TripServiceError.noNetwork) {
            try await service.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        }
    }
}
