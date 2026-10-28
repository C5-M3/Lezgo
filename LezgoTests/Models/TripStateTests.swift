//
//  TripStateTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation
import Testing
@testable import Lezgo

struct TripStateTests {
    @Test func LeaderIsTheParticipantTheTripNames() {
        let participants = [
            TripFixtures.Participant(id: TripFixtures.budiID),
            TripFixtures.Participant(id: TripFixtures.agusID)
        ]
        let state = TripState(trip: TripFixtures.Trip(), waypoints: [], participants: participants, route: nil)

        #expect(state.leader?.id == TripFixtures.agusID)
    }

    @Test func NoLeaderWhenTheLeaderIsNotInTheList() {
        let participants = [TripFixtures.Participant()]
        let state = TripState(trip: TripFixtures.Trip(), waypoints: [], participants: participants, route: nil)

        #expect(state.leader == nil)
    }

    @Test func DestinationIsTheDestinationWaypoint() {
        let waypoints = [
            TripFixtures.Waypoint(orderIndex: 0, kind: .start),
            TripFixtures.Waypoint(orderIndex: 1, kind: .destination)
        ]
        let state = TripState(trip: TripFixtures.Trip(), waypoints: waypoints, participants: [], route: nil)

        #expect(state.destination?.orderIndex == 1)
    }
}
