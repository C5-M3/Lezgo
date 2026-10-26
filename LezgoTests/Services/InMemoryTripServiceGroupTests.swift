import Foundation
import Testing
@testable import Lezgo

/// How start, group actions, exit and end behave. `LiveTripService` must follow the same rules (ADR 0017).
struct InMemoryTripServiceGroupTests {
    let phones = InMemoryPhones()

    @Test func StartTripPutsEveryoneOnTheRoad() async throws {
        let group = try await phones.MakeGroup()

        try await phones.agus.StartTrip(tripID: group.tripID, by: group.agusID)

        let trip = try await phones.budi.FetchTrip(tripID: group.tripID).trip
        #expect(trip.status == .inTrip)
        #expect(trip.startedAt == TripFixtures.now)
        #expect(trip.currentWaypointIndex == 1)
    }

    @Test func MemberCannotStartTheTrip() async throws {
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.StartTrip(tripID: group.tripID, by: group.budiID)
        }
    }

    @Test func LeaderRemovesMembers() async throws {
        let group = try await phones.MakeGroup()

        try await phones.agus.RemoveParticipants([group.budiID, group.citraID], tripID: group.tripID, by: group.agusID)

        let state = try await phones.agus.FetchTrip(tripID: group.tripID)
        #expect(state.participants.map(\.id) == [group.agusID])
    }

    @Test func MemberCannotRemoveAnyone() async throws {
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.RemoveParticipants([group.citraID], tripID: group.tripID, by: group.budiID)
        }
    }

    @Test func LeaderCannotRemoveThemselves() async throws {
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.agus.RemoveParticipants([group.agusID], tripID: group.tripID, by: group.agusID)
        }
    }

    @Test func LeaderHandsOverTheLead() async throws {
        let group = try await phones.MakeGroup()

        try await phones.agus.SetLeader(group.budiID, tripID: group.tripID, replacing: group.agusID)

        #expect(try await phones.agus.FetchTrip(tripID: group.tripID).leader?.id == group.budiID)
    }

    @Test func SecondPickOfANewLeaderLoses() async throws {
        let group = try await phones.MakeGroup()

        try await phones.budi.SetLeader(group.citraID, tripID: group.tripID, replacing: group.agusID)

        await #expect(throws: TripServiceError.conflict) {
            try await phones.citra.SetLeader(group.budiID, tripID: group.tripID, replacing: group.agusID)
        }
        #expect(try await phones.agus.FetchTrip(tripID: group.tripID).leader?.id == group.citraID)
    }

    @Test func NewLeaderMustBeInTheTrip() async throws {
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notFound) {
            try await phones.agus.SetLeader(UUID(), tripID: group.tripID, replacing: group.agusID)
        }
    }

    @Test func MemberExitsAndDisappearsFromTheTrip() async throws {
        let group = try await phones.MakeGroup()

        try await phones.budi.ExitTrip(tripID: group.tripID, participantID: group.budiID)

        let state = try await phones.agus.FetchTrip(tripID: group.tripID)
        #expect(state.participants.contains { $0.id == group.budiID } == false)
        #expect(state.trip.status == .lobby)
    }

    @Test func LeaderCannotExitWithoutEndingOrHandingOver() async throws {
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.agus.ExitTrip(tripID: group.tripID, participantID: group.agusID)
        }
    }

    @Test func LeaderEndingTheTripRoomCancelsIt() async throws {
        let group = try await phones.MakeGroup()

        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        let trip = try await phones.budi.FetchTrip(tripID: group.tripID).trip
        #expect(trip.status == .cancelled)
        #expect(trip.endedAt == TripFixtures.now)
    }

    @Test func LeaderEndingTheTripOnTheRoadEndsIt() async throws {
        let group = try await phones.MakeGroupOnTheRoad()

        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        #expect(try await phones.budi.FetchTrip(tripID: group.tripID).trip.status == .ended)
    }

    @Test func EndingAnEndedTripChangesNothing() async throws {
        let group = try await phones.MakeGroup()
        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        #expect(try await phones.budi.FetchTrip(tripID: group.tripID).trip.status == .cancelled)
    }

    @Test func MemberCannotEndTheTrip() async throws {
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.EndTrip(tripID: group.tripID, by: group.budiID)
        }
    }

    @Test func EndedTripCannotBeChanged() async throws {
        let group = try await phones.MakeGroup()
        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        await #expect(throws: TripServiceError.tripEnded) {
            try await phones.agus.StartTrip(tripID: group.tripID, by: group.agusID)
        }
    }
}
