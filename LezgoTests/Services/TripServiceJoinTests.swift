import Foundation
import Testing
@testable import Lezgo

/// How joining, fetching and listening behave, for both implementations (ADR 0017).
struct TripServiceJoinTests {
    @Test(arguments: TripPhones.Kind.allCases)
    func MemberJoinsTheLobby(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let created = try await phones.agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        let joined = try await phones.budi.JoinTrip(
            roomCode: created.state.trip.roomCode,
            profile: TripPlanFixtures.budiProfile
        )

        #expect(joined.state.trip.id == created.state.trip.id)
        #expect(joined.state.participants.count == 2)
        let budi = try #require(joined.state.participants.first { $0.id == joined.myParticipantID })
        #expect(budi.displayName == "Budi")
        #expect(budi.IsLeader(in: joined.state.trip) == false)
        #expect(budi.motionState == .stopped)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func MemberJoinsLateWhileTheTripIsOnTheRoad(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let created = try await phones.agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        try await phones.agus.StartTrip(tripID: created.state.trip.id, by: created.myParticipantID)

        let joined = try await phones.budi.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)

        #expect(joined.state.trip.status == .inTrip)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func JoiningAgainReturnsTheSameCar(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        let again = try await phones.budi.JoinTrip(roomCode: group.roomCode, profile: TripPlanFixtures.budiProfile)

        #expect(again.myParticipantID == group.budiID)
        #expect(again.state.participants.count == 3)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func UnknownRoomCodeIsNotFound(kind: TripPhones.Kind) async {
        let phones = TripPhones(kind)
        await #expect(throws: TripServiceError.notFound) {
            try await phones.budi.JoinTrip(roomCode: "000000", profile: nil)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases, [TripStatus.ended, .cancelled])
    func ClosedTripCannotBeJoined(kind: TripPhones.Kind, status: TripStatus) async throws {
        let phones = TripPhones(kind)
        let created = try await phones.agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let tripID = created.state.trip.id
        if status == .ended {
            try await phones.agus.StartTrip(tripID: tripID, by: created.myParticipantID)
        }
        try await phones.agus.EndTrip(tripID: tripID, by: created.myParticipantID)

        await #expect(throws: TripServiceError.tripEnded) {
            try await phones.budi.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func FetchReturnsTheTripAsItIsNow(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        let state = try await phones.budi.FetchTrip(tripID: group.tripID)

        #expect(state.participants.count == 3)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func FetchingAnUnknownTripIsNotFound(kind: TripPhones.Kind) async {
        let phones = TripPhones(kind)
        await #expect(throws: TripServiceError.notFound) {
            try await phones.budi.FetchTrip(tripID: UUID())
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func UpdatesSendTheTripRightAwayThenEveryChange(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()
        var updates = phones.budi.TripUpdates(tripID: group.tripID).makeAsyncIterator()

        let first = await updates.next()
        try await phones.agus.StartTrip(tripID: group.tripID, by: group.agusID)
        let second = await updates.next()

        #expect(first?.trip.status == .lobby)
        #expect(second?.trip.status == .inTrip)
    }
}
