//
//  TripServiceCreateTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// How `TripService.CreateTrip` behaves, for both implementations (ADR 0017).
struct TripServiceCreateTests {
    @Test(arguments: TripPhones.Kind.allCases)
    func NewTripWaitsInTheLobbyWithTheCreatorAsLeader(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
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

    @Test(arguments: TripPhones.Kind.allCases)
    func NewTripHasASixDigitRoomCode(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let session = try await phones.agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let roomCode = session.state.trip.roomCode

        #expect(roomCode.count == 6)
        #expect(roomCode.allSatisfy { $0.isASCII && $0.isNumber })
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func NewTripKeepsTheWaypointsInOrder(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let session = try await phones.agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        #expect(session.state.waypoints.map(\.orderIndex) == [0, 1, 2])
        #expect(session.state.waypoints.map(\.kind) == [.start, .checkpoint, .destination])
        #expect(session.state.destination?.name == "Pakuwon mall")
        #expect(session.state.route?.version == 1)
        #expect(session.state.route?.polyline == TripPlanFixtures.tunjunganToPakuwon.polyline)
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func PlanWithoutADestinationIsRejected(kind: TripPhones.Kind) async {
        let phones = TripPhones(kind)
        let plan = TripPlan(waypoints: [TripPlanFixtures.tunjunganToPakuwon.waypoints[0]], polyline: [])

        await #expect(throws: TripServiceError.notAllowed) {
            try await phones.agus.CreateTrip(plan: plan, profile: nil)
        }
    }

    @Test(arguments: TripPhones.Kind.allCases)
    func NameDefaultsToMemberAndTheEndOfTheICloudID(kind: TripPhones.Kind) async throws {
        let phones = TripPhones(kind)
        let session = try await phones.budi.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        #expect(session.state.leader?.displayName == "Member 7F3A")
    }
}
