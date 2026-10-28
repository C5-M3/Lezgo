//
//  WaypointTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Testing
@testable import Lezgo

struct WaypointTests {
    @Test(arguments: [
        (currentWaypointIndex: 0, isVisited: false),
        (currentWaypointIndex: 1, isVisited: false),
        (currentWaypointIndex: 2, isVisited: true),
        (currentWaypointIndex: 5, isVisited: true)
    ])
    func WaypointIsVisitedOnlyOnceTheTripMovesPastIt(currentWaypointIndex: Int, isVisited: Bool) {
        let checkpoint = TripFixtures.Waypoint(orderIndex: 1)

        #expect(checkpoint.IsVisited(currentWaypointIndex: currentWaypointIndex) == isVisited)
    }

    @Test func StartPointIsVisitedOnceTheTripStarts() {
        let startPoint = TripFixtures.Waypoint(orderIndex: 0, kind: .start)

        #expect(startPoint.IsVisited(currentWaypointIndex: 0) == false)
        #expect(startPoint.IsVisited(currentWaypointIndex: 1))
    }
}
