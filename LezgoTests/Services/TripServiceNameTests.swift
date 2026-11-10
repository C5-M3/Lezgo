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
    /// The only place to rename is Edit Profile inside the room, so a clash on join must not keep the person out:
    /// they join with the name left empty (shown as "Car 2") and keep their car.
    @Test(arguments: TripPhones.Kind.allCases)
    func JoiningWithANameAnotherCarHasStillReachesTheRoomWithoutThatName(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let created = try await phones.agus.CreateTrip(
            plan: TripPlanFixtures.tunjunganToPakuwon,
            profile: TripPlanFixtures.agusProfile
        )

        let session = try await phones.budi.JoinTrip(
            roomCode: created.state.trip.roomCode,
            profile: ParticipantProfile(displayName: "  agus ", carDescription: "White Brio", avatar: .pink)
        )

        let state = try await phones.agus.FetchTrip(tripID: created.state.trip.id)
        #expect(state.participants.count == 2)
        let budi = try #require(state.participants.first { $0.id == session.myParticipantID })
        #expect(budi.displayName.isEmpty)
        #expect(budi.carDescription == "White Brio")
        #expect(Avatar.memberAvatars.contains(budi.avatar))
        #expect(state.DisplayName(of: budi) == String(localized: .participantCarName(2)))
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func ALateJoinerWithTheTakenNameCanRenameAfterwards(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let created = try await phones.agus.CreateTrip(
            plan: TripPlanFixtures.tunjunganToPakuwon,
            profile: TripPlanFixtures.agusProfile
        )
        let session = try await phones.budi.JoinTrip(
            roomCode: created.state.trip.roomCode,
            profile: ParticipantProfile(displayName: "Agus", carDescription: "White Brio")
        )

        try await phones.budi.UpdateProfile(
            ParticipantProfile(displayName: "Budi", carDescription: "White Brio"),
            participantID: session.myParticipantID,
            tripID: created.state.trip.id
        )

        let state = try await phones.agus.FetchTrip(tripID: created.state.trip.id)
        #expect(state.participants.first { $0.id == session.myParticipantID }?.displayName == "Budi")
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
