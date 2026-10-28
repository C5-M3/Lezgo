//
//  ParticipantTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation
import Testing
@testable import Lezgo

struct ParticipantTests {
    @Test func LeaderIsTheParticipantNamedOnTheTrip() {
        let agus = TripFixtures.Participant(id: TripFixtures.agusID)
        let budi = TripFixtures.Participant(id: TripFixtures.budiID)
        let trip = TripFixtures.Trip()

        #expect(agus.IsLeader(in: trip))
        #expect(budi.IsLeader(in: trip) == false)
    }

    @Test func LeaderChangesWithTheTrip() {
        let budi = TripFixtures.Participant(id: TripFixtures.budiID)
        var trip = TripFixtures.Trip()

        trip.leaderParticipantID = TripFixtures.budiID

        #expect(budi.IsLeader(in: trip))
    }

    @Test(arguments: [
        (secondsAgo: 0.0, isOnline: true),
        (secondsAgo: 119.0, isOnline: true),
        (secondsAgo: 120.0, isOnline: true),
        (secondsAgo: 121.0, isOnline: false),
        (secondsAgo: 300.0, isOnline: false)
    ])
    func ParticipantIsOfflineOnlyAfterTwoMinutes(secondsAgo: TimeInterval, isOnline: Bool) {
        let budi = TripFixtures.Participant(lastSeenSecondsAgo: secondsAgo)

        #expect(budi.IsOnline(at: TripFixtures.now) == isOnline)
    }

    @Test func LastSeenSlightlyInTheFutureIsOnline() {
        // Phone clocks drift, so another phone's timestamp can be ahead of ours.
        let budi = TripFixtures.Participant(lastSeenSecondsAgo: -5)

        #expect(budi.IsOnline(at: TripFixtures.now))
    }
}
