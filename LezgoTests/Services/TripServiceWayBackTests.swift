//
//  TripServiceWayBackTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 2/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// A member's way back reaches the leader's phone (`specs/UserStories.md` → US-06, "Footprint"), with both services.
struct TripServiceWayBackTests {
    private let wayBack = [
        Coordinate(latitude: -7.2620, longitude: 112.7380),
        Coordinate(latitude: -7.2640, longitude: 112.7370)
    ]

    @Test(arguments: TripPhones.Kind.allCases)
    func MembersWayBackReachesTheLeader(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()

        try await phones.budi.SetWayBack(wayBack, participantID: group.budiID, tripID: group.tripID)

        #expect(try await phones.Budi(in: group)?.wayBack == wayBack)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func EmptyWayBackClearsIt(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()
        try await phones.budi.SetWayBack(wayBack, participantID: group.budiID, tripID: group.tripID)

        try await phones.budi.SetWayBack([], participantID: group.budiID, tripID: group.tripID)

        #expect(try await phones.Budi(in: group)?.wayBack.isEmpty == true)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func NewPositionKeepsTheWayBack(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()
        try await phones.budi.SetWayBack(wayBack, participantID: group.budiID, tripID: group.tripID)
        let update = LocationUpdate(
            coordinate: wayBack[0],
            speedKmh: 30,
            motionState: .driving,
            recordedAt: TripFixtures.now
        )

        try await phones.budi.UpdateLocation(update, participantID: group.budiID, tripID: group.tripID)

        #expect(try await phones.Budi(in: group)?.wayBack == wayBack)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func LeaderHasNoWayBack(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.agus.SetWayBack(wayBack, participantID: group.agusID, tripID: group.tripID)
        }
    }
}
