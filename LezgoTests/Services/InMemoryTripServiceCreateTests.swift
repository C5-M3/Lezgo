import Foundation
import Testing
@testable import Lezgo

/// How `TripService.CreateTrip` behaves. `LiveTripService` must follow the same rules (ADR 0017).
struct InMemoryTripServiceCreateTests {
    let phones = InMemoryPhones()

    @Test func NewTripWaitsInTheLobbyWithTheCreatorAsLeader() async throws {
        let session = try await phones.agus.CreateTrip(
            plan: TripPlanFixtures.tunjunganToPakuwon,
            profile: TripPlanFixtures.agusProfile
        )
        let state = session.state

        #expect(state.trip.status == .lobby)
        #expect(state.trip.leaderParticipantID == session.myParticipantID)
        #expect(state.trip.currentWaypointIndex == 0)
        #expect(state.trip.routeVersion == 1)
        #expect(state.leader?.displayName == "Agus")
        #expect(state.participants.count == 1)
    }

    @Test func NewTripHasASixDigitRoomCode() async throws {
        let session = try await phones.agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let roomCode = session.state.trip.roomCode

        #expect(roomCode.count == 6)
        #expect(roomCode.allSatisfy { $0.isASCII && $0.isNumber })
    }

    @Test func NewTripKeepsTheWaypointsInOrder() async throws {
        let session = try await phones.agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        #expect(session.state.waypoints.map(\.orderIndex) == [0, 1, 2])
        #expect(session.state.waypoints.map(\.kind) == [.start, .checkpoint, .destination])
        #expect(session.state.destination?.name == "Pakuwon mall")
        #expect(session.state.route?.version == 1)
        #expect(session.state.route?.polyline == TripPlanFixtures.tunjunganToPakuwon.polyline)
    }

    @Test func RoomCodeInUseIsNotGivenTwice() async throws {
        var codes = ["111111", "111111", "222222"]
        let makeRoomCode = { codes.removeFirst() }
        let first = InMemoryTripService(store: phones.store, userRecordID: "_one", makeRoomCode: makeRoomCode)
        let second = InMemoryTripService(store: phones.store, userRecordID: "_two", makeRoomCode: makeRoomCode)

        let firstTrip = try await first.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let secondTrip = try await second.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        #expect(firstTrip.state.trip.roomCode == "111111")
        #expect(secondTrip.state.trip.roomCode == "222222")
    }

    @Test func PlanWithoutADestinationIsRejected() async {
        let plan = TripPlan(waypoints: [TripPlanFixtures.tunjunganToPakuwon.waypoints[0]], polyline: [])

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.agus.CreateTrip(plan: plan, profile: nil)
        }
    }

    @Test func NameDefaultsToMemberAndTheEndOfTheICloudID() async throws {
        let session = try await phones.budi.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        #expect(session.state.leader?.displayName == "Member 7F3A")
    }

    @Test func SimulatedFailureIsThrown() async {
        phones.agus.simulatedFailure = .noNetwork

        await #expect(throws: TripServiceError.noNetwork) {
            try await phones.agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        }
    }
}
