//
//  TripServiceTrailTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The leader's footprint reaches every phone (`specs/UserStories.md` → US-06, "Footprint"), with both services.
struct TripServiceTrailTests {
    private let trail = [
        Coordinate(latitude: -7.2620, longitude: 112.7380),
        Coordinate(latitude: -7.2640, longitude: 112.7370)
    ]

    @Test(arguments: TripPhones.Kind.allCases)
    func LeadersFootprintReachesTheMembers(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()

        try await phones.agus.SaveTrail(trail, tripID: group.tripID, by: group.agusID)

        #expect(try await phones.budi.FetchTrip(tripID: group.tripID).trail == trail)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func NoFootprintBeforeTheLeaderSavesOne(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()

        #expect(try await phones.budi.FetchTrip(tripID: group.tripID).trail.isEmpty)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func MemberCannotSaveTheFootprint(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.SaveTrail(trail, tripID: group.tripID, by: group.budiID)
        }
    }
}
