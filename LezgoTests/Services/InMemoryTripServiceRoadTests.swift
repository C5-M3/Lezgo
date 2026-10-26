import Foundation
import Testing
@testable import Lezgo

/// How location, alerts, checkpoints, routes and profiles behave. `LiveTripService` must follow the same rules.
struct InMemoryTripServiceRoadTests {
    let phones = InMemoryPhones()

    private func Update(at coordinate: Coordinate, speedKmh: Double, secondsLater: TimeInterval) -> LocationUpdate {
        LocationUpdate(
            coordinate: coordinate,
            speedKmh: speedKmh,
            motionState: speedKmh > 0 ? .driving : .stopped,
            recordedAt: TripFixtures.now.addingTimeInterval(secondsLater)
        )
    }

    @Test func LocationUpdateMovesMyCar() async throws {
        let group = try await phones.MakeGroupOnTheRoad()
        let update = Update(at: TripFixtures.ciputraWorld, speedKmh: 52, secondsLater: 5)

        try await phones.budi.UpdateLocation(update, participantID: group.budiID, tripID: group.tripID)

        let budi = try #require(try await phones.Budi(in: group))
        #expect(budi.coordinate == TripFixtures.ciputraWorld)
        #expect(budi.speedKmh == 52)
        #expect(budi.motionState == .driving)
        #expect(budi.lastSeenAt == update.recordedAt)
    }

    @Test func LocationOfAMemberWhoLeftIsNotFound() async throws {
        let group = try await phones.MakeGroupOnTheRoad()
        try await phones.budi.ExitTrip(tripID: group.tripID, participantID: group.budiID)
        let update = Update(at: TripFixtures.ciputraWorld, speedKmh: 0, secondsLater: 1)

        await #expect(throws: TripServiceError.notFound) {
            try await phones.budi.UpdateLocation(update, participantID: group.budiID, tripID: group.tripID)
        }
    }

    @Test func MemberAlertIsSaved() async throws {
        let group = try await phones.MakeGroupOnTheRoad()

        try await phones.budi.SetAlert(.offRoute, participantID: group.budiID, tripID: group.tripID)

        #expect(try await phones.Budi(in: group)?.alert == .offRoute)
    }

    @Test func LeaderNeverHasAnAlert() async throws {
        let group = try await phones.MakeGroupOnTheRoad()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.agus.SetAlert(.offRoute, participantID: group.agusID, tripID: group.tripID)
        }
    }

    @Test func CheckpointsOnlyMoveForward() async throws {
        let group = try await phones.MakeGroupOnTheRoad()

        try await phones.agus.AdvanceCheckpoint(to: 2, tripID: group.tripID, by: group.agusID)
        try await phones.agus.AdvanceCheckpoint(to: 1, tripID: group.tripID, by: group.agusID)

        #expect(try await phones.budi.FetchTrip(tripID: group.tripID).trip.currentWaypointIndex == 2)
    }

    @Test func MemberCannotAdvanceACheckpoint() async throws {
        let group = try await phones.MakeGroupOnTheRoad()

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.budi.AdvanceCheckpoint(to: 2, tripID: group.tripID, by: group.budiID)
        }
    }

    @Test func NewRouteOnTheRoadIsTheNextVersion() async throws {
        let group = try await phones.MakeGroupOnTheRoad()
        try await phones.agus.AdvanceCheckpoint(to: 2, tripID: group.tripID, by: group.agusID)

        try await phones.agus.SaveRoute(TripPlanFixtures.ciputraToPakuwonCity, tripID: group.tripID, by: group.agusID)

        let state = try await phones.budi.FetchTrip(tripID: group.tripID)
        #expect(state.trip.routeVersion == 2)
        #expect(state.route?.version == 2)
        #expect(state.trip.currentWaypointIndex == 1)
        #expect(state.trip.status == .inTrip)
        #expect(state.destination?.name == "Pakuwon city mall")
    }

    @Test func NewDestinationGoesBackToTheTripRoom() async throws {
        let group = try await phones.MakeGroupOnTheRoad()

        try await phones.agus.StartNewDestination(
            TripPlanFixtures.ciputraToPakuwonCity,
            tripID: group.tripID,
            by: group.agusID
        )

        let state = try await phones.budi.FetchTrip(tripID: group.tripID)
        #expect(state.trip.status == .lobby)
        #expect(state.trip.currentWaypointIndex == 0)
        #expect(state.trip.routeVersion == 2)
        #expect(state.trip.roomCode == group.roomCode)
        #expect(state.participants.count == 3)
    }

    @Test func ProfileChangeShowsToEveryone() async throws {
        let group = try await phones.MakeGroup()
        let profile = ParticipantProfile(displayName: "Budi Santoso", carDescription: "Silver Brio")

        try await phones.budi.UpdateProfile(profile, participantID: group.budiID, tripID: group.tripID)

        let budi = try #require(try await phones.Budi(in: group))
        #expect(budi.displayName == "Budi Santoso")
        #expect(budi.carDescription == "Silver Brio")
    }
}
