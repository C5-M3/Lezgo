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

    // MARK: Names

    /// A car whose driver typed no name: iOS does not tell apps the iCloud account's name.
    private func Unnamed(_ id: UUID = UUID()) -> Participant {
        var participant = TripFixtures.Participant(id: id)
        participant.displayName = ""
        return participant
    }

    @Test func UnnamedLeaderIsCalledLeader() {
        let state = TripState(
            trip: TripFixtures.Trip(),
            waypoints: [],
            participants: [Unnamed(TripFixtures.agusID)],
            route: nil
        )

        #expect(state.DisplayName(of: state.participants[0]) == "Leader")
    }

    @Test func UnnamedMembersAreNumberedInTheOrderTheyJoined() {
        // The leader counts as car 1, so the first member is car 2, wherever the leader is in the list.
        let first = Unnamed()
        let second = Unnamed()
        let state = TripState(
            trip: TripFixtures.Trip(),
            waypoints: [],
            participants: [first, Unnamed(TripFixtures.agusID), second],
            route: nil
        )

        #expect(state.DisplayName(of: first) == "Car 2")
        #expect(state.DisplayName(of: second) == "Car 3")
    }

    @Test func TypedNameIsKept() {
        var budi = Unnamed()
        budi.displayName = "Budi"
        let state = TripState(trip: TripFixtures.Trip(), waypoints: [], participants: [budi], route: nil)

        #expect(state.DisplayName(of: budi) == "Budi")
    }

    @Test func NameOfOnlySpacesCountsAsNoName() {
        var member = Unnamed()
        member.displayName = "   "
        let state = TripState(
            trip: TripFixtures.Trip(),
            waypoints: [],
            participants: [Unnamed(TripFixtures.agusID), member],
            route: nil
        )

        #expect(state.DisplayName(of: member) == "Car 2")
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
