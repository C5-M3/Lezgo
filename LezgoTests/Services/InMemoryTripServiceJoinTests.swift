import Foundation
import Testing
@testable import Lezgo

/// How joining, fetching and listening behave. `LiveTripService` must follow the same rules (ADR 0017).
struct InMemoryTripServiceJoinTests {
    let phones = InMemoryPhones()

    @Test func MemberJoinsTheLobby() async throws {
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

    @Test func MemberJoinsLateWhileTheTripIsOnTheRoad() async throws {
        let created = try await phones.agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        try await phones.agus.StartTrip(tripID: created.state.trip.id, by: created.myParticipantID)

        let joined = try await phones.budi.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)

        #expect(joined.state.trip.status == .inTrip)
    }

    @Test func JoiningAgainReturnsTheSameCar() async throws {
        let group = try await phones.MakeGroup()

        let again = try await phones.budi.JoinTrip(roomCode: group.roomCode, profile: TripPlanFixtures.budiProfile)

        #expect(again.myParticipantID == group.budiID)
        #expect(again.state.participants.count == 3)
    }

    @Test func UnknownRoomCodeIsNotFound() async {
        await #expect(throws: TripServiceError.notFound) {
            try await phones.budi.JoinTrip(roomCode: "000000", profile: nil)
        }
    }

    @Test(arguments: [TripStatus.ended, .cancelled])
    func ClosedTripCannotBeJoined(status: TripStatus) async throws {
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

    @Test func FetchReturnsTheTripAsItIsNow() async throws {
        let group = try await phones.MakeGroup()

        let state = try await phones.budi.FetchTrip(tripID: group.tripID)

        #expect(state.participants.count == 3)
    }

    @Test func FetchingAnUnknownTripIsNotFound() async {
        await #expect(throws: TripServiceError.notFound) {
            try await phones.budi.FetchTrip(tripID: UUID())
        }
    }

    @Test func UpdatesSendTheTripRightAwayThenEveryChange() async throws {
        let group = try await phones.MakeGroup()
        var updates = phones.budi.TripUpdates(tripID: group.tripID).makeAsyncIterator()

        let first = await updates.next()
        try await phones.agus.StartTrip(tripID: group.tripID, by: group.agusID)
        let second = await updates.next()

        #expect(first?.trip.status == .lobby)
        #expect(second?.trip.status == .inTrip)
    }
}
