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

    @Test(arguments: [(currentWaypointIndex: 1, next: Int?.some(1)), (2, 2), (3, nil)])
    func NextCheckpointIsTheFirstOneNotVisited(currentWaypointIndex: Int, next: Int?) {
        let waypoints = [
            TripFixtures.Waypoint(orderIndex: 0, kind: .start),
            TripFixtures.Waypoint(orderIndex: 2, kind: .checkpoint),
            TripFixtures.Waypoint(orderIndex: 1, kind: .checkpoint),
            TripFixtures.Waypoint(orderIndex: 3, kind: .destination)
        ]
        let state = TripState(
            trip: TripFixtures.Trip(currentWaypointIndex: currentWaypointIndex),
            waypoints: waypoints,
            participants: [],
            route: nil
        )

        #expect(state.nextCheckpoint?.orderIndex == next)
    }
}
