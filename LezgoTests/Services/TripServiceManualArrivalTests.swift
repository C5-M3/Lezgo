//
//  TripServiceManualArrivalTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// "I've Arrived": a driver whose destination point is a little off, such as the far side of a big mall, says they
/// have arrived (`specs/UserStories.md` → US-07, "Arrive"), with both services.
struct TripServiceManualArrivalTests {
    private func DestinationID(_ phones: TripPhones, _ group: TripGroup) async throws -> UUID {
        try #require(try await phones.agus.FetchTrip(tripID: group.tripID).destination?.id)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func MembersArrivalReachesEveryPhone(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()
        let destinationID = try await DestinationID(phones, group)

        try await phones.budi.MarkArrived(at: destinationID, participantID: group.budiID, tripID: group.tripID)

        #expect(try await phones.Budi(in: group)?.arrivedAtWaypointID == destinationID)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func TheLeaderCanSayTheyArrivedToo(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()
        let destinationID = try await DestinationID(phones, group)

        try await phones.agus.MarkArrived(at: destinationID, participantID: group.agusID, tripID: group.tripID)

        let agus = try await phones.budi.FetchTrip(tripID: group.tripID).participants.first { $0.id == group.agusID }
        #expect(agus?.arrivedAtWaypointID == destinationID)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func NewPositionKeepsTheArrival(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()
        let destinationID = try await DestinationID(phones, group)
        try await phones.budi.MarkArrived(at: destinationID, participantID: group.budiID, tripID: group.tripID)
        let update = LocationUpdate(
            coordinate: Coordinate(latitude: -7.2893, longitude: 112.6766),
            speedKmh: 0,
            motionState: .stopped,
            recordedAt: TripFixtures.now
        )

        try await phones.budi.UpdateLocation(update, participantID: group.budiID, tripID: group.tripID)

        #expect(try await phones.Budi(in: group)?.arrivedAtWaypointID == destinationID)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func NobodyArrivesBeforeTheTripStarts(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()
        let destinationID = try await DestinationID(phones, group)

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.MarkArrived(at: destinationID, participantID: group.budiID, tripID: group.tripID)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func OnlyTheCurrentDestinationCanBeReached(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.MarkArrived(at: UUID(), participantID: group.budiID, tripID: group.tripID)
        }
    }
}
