import Foundation
import Testing
@testable import Lezgo

/// How start, group actions, exit and end behave, for both implementations (ADR 0017).
struct TripServiceGroupTests {
    @Test(arguments: TripPhones.Kind.allCases)
    func StartTripPutsEveryoneOnTheRoad(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        try await phones.agus.StartTrip(tripID: group.tripID, by: group.agusID)

        let trip = try await phones.budi.FetchTrip(tripID: group.tripID).trip
        #expect(trip.status == .inTrip)
        #expect(trip.startedAt == TripFixtures.now)
        #expect(trip.currentWaypointIndex == 1)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func MemberCannotStartTheTrip(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.StartTrip(tripID: group.tripID, by: group.budiID)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func LeaderRemovesMembers(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        try await phones.agus.RemoveParticipants([group.budiID, group.citraID], tripID: group.tripID, by: group.agusID)

        let state = try await phones.agus.FetchTrip(tripID: group.tripID)
        #expect(state.participants.map(\.id) == [group.agusID])
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func MemberCannotRemoveAnyone(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.RemoveParticipants([group.citraID], tripID: group.tripID, by: group.budiID)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func LeaderCannotRemoveThemselves(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.agus.RemoveParticipants([group.agusID], tripID: group.tripID, by: group.agusID)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func LeaderHandsOverTheLead(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        try await phones.agus.SetLeader(group.budiID, tripID: group.tripID, replacing: group.agusID)

        #expect(try await phones.agus.FetchTrip(tripID: group.tripID).leader?.id == group.budiID)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func SecondPickOfANewLeaderLoses(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        try await phones.budi.SetLeader(group.citraID, tripID: group.tripID, replacing: group.agusID)

        await #expect(throws: TripServiceError.conflict) {
            try await phones.citra.SetLeader(group.budiID, tripID: group.tripID, replacing: group.agusID)
        }
        #expect(try await phones.agus.FetchTrip(tripID: group.tripID).leader?.id == group.citraID)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func NewLeaderMustBeInTheTrip(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notFound) {
            try await phones.agus.SetLeader(UUID(), tripID: group.tripID, replacing: group.agusID)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func MemberExitsAndDisappearsFromTheTrip(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        try await phones.budi.ExitTrip(tripID: group.tripID, participantID: group.budiID)

        let state = try await phones.agus.FetchTrip(tripID: group.tripID)
        #expect(state.participants.contains { $0.id == group.budiID } == false)
        #expect(state.trip.status == .lobby)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func LeaderCannotExitWithoutEndingOrHandingOver(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.agus.ExitTrip(tripID: group.tripID, participantID: group.agusID)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func LeaderEndingTheTripRoomCancelsIt(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        let trip = try await phones.budi.FetchTrip(tripID: group.tripID).trip
        #expect(trip.status == .cancelled)
        #expect(trip.endedAt == TripFixtures.now)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func LeaderEndingTheTripOnTheRoadEndsIt(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroupOnTheRoad()

        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        #expect(try await phones.budi.FetchTrip(tripID: group.tripID).trip.status == .ended)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func EndingAnEndedTripChangesNothing(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()
        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        #expect(try await phones.budi.FetchTrip(tripID: group.tripID).trip.status == .cancelled)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func MemberCannotEndTheTrip(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.EndTrip(tripID: group.tripID, by: group.budiID)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func EndedTripCannotBeChanged(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let group = try await phones.MakeGroup()
        try await phones.agus.EndTrip(tripID: group.tripID, by: group.agusID)

        await #expect(throws: TripServiceError.tripEnded) {
            try await phones.agus.StartTrip(tripID: group.tripID, by: group.agusID)
        }
    }
}
