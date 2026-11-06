//
//  TripServiceNameTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 06/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Names are unique in a trip, ignoring upper/lower case and spaces at the ends (US-04, "Edit Profile"; US-02), for
/// both implementations (ADR 0017).
struct TripServiceNameTests {
    @Test(arguments: TripPhones.Kind.allCases)
    func JoiningWithANameAnotherCarHasIsRejected(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let created = try await phones.agus.CreateTrip(
            plan: TripPlanFixtures.tunjunganToPakuwon,
            profile: TripPlanFixtures.agusProfile
        )

        await #expect(throws: TripServiceError.nameAlreadyUsed) {
            try await phones.budi.JoinTrip(
                roomCode: created.state.trip.roomCode,
                profile: ParticipantProfile(displayName: "  agus ", carDescription: "White Brio")
            )
        }
        let state = try await phones.agus.FetchTrip(tripID: created.state.trip.id)
        #expect(state.participants.count == 1)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func JoiningAgainWithMyOwnNameStillReturnsMyCar(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        let again = try await phones.budi.JoinTrip(roomCode: group.roomCode, profile: TripPlanFixtures.budiProfile)

        #expect(again.myParticipantID == group.budiID)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func RenamingToANameAnotherCarHasIsRejected(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()
        let profile = ParticipantProfile(displayName: " CITRA", carDescription: "White Brio")

        await #expect(throws: TripServiceError.nameAlreadyUsed) {
            try await phones.budi.UpdateProfile(profile, participantID: group.budiID, tripID: group.tripID)
        }
        let budi = try await phones.Budi(in: group)
        #expect(budi?.displayName == "Budi")
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func LeaderRenamingAMemberToATakenNameIsRejected(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()
        let profile = ParticipantProfile(displayName: "Citra", carDescription: "White Brio")

        await #expect(throws: TripServiceError.nameAlreadyUsed) {
            try await phones.agus.UpdateProfile(profile, participantID: group.budiID, tripID: group.tripID)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func KeepingMyOwnNameIsNotAClash(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()
        let profile = ParticipantProfile(displayName: "budi", carDescription: "Black Jazz")

        try await phones.budi.UpdateProfile(profile, participantID: group.budiID, tripID: group.tripID)

        let budi = try await phones.Budi(in: group)
        #expect(budi?.carDescription == "Black Jazz")
    }
}
