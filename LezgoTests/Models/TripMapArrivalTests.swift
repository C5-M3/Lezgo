//
//  TripMapArrivalTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation
import Testing
@testable import Lezgo

struct TripMapArrivalTests {
    private typealias Fixtures = TripMapFixtures

    private func Check(_ cars: [Participant]) -> TripMapArrival {
        TripMapArrival.Check(Fixtures.State(cars: cars), myParticipantID: Fixtures.budiID, at: Fixtures.now)
    }

    @Test(arguments: [(metres: 0.0, arrived: true), (19, true), (21, false), (500, false)])
    func MyCarArrivesWithinTwentyMetres(metres: Double, arrived: Bool) {
        let budi = Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: metres)

        #expect(Check([budi]).hasArrived == arrived)
    }

    @Test func EveryoneArrivedWhenAllCarsAreThere() {
        let arrival = Check([
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: 5),
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: 15)
        ])

        #expect(arrival.hasArrived)
        #expect(arrival.everyoneHasArrived)
    }

    @Test func OneLateCarMeansNotEveryone() {
        let arrival = Check([
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: 5),
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: 500)
        ])

        #expect(arrival.hasArrived)
        #expect(arrival.everyoneHasArrived == false)
    }

    @Test func OfflineCarCountsAsNotArrived() {
        let arrival = Check([
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: 5, lastSeenSecondsAgo: 180)
        ])

        #expect(arrival.everyoneHasArrived == false)
    }

    @Test func MemberWithoutAPositionCountsAsNotArrived() {
        var citra = Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: 5)
        citra.coordinate = nil

        let arrival = Check([Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10), citra])

        #expect(arrival.everyoneHasArrived == false)
    }

    @Test func MemberWhoLeftIsNotCounted() {
        // Citra exited: she is no longer in the trip, so only Budi counts.
        let arrival = Check([Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10)])

        #expect(arrival.everyoneHasArrived)
    }

    @Test func NoDestinationMeansNobodyArrived() {
        let budi = Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 0)
        let state = Fixtures.State(cars: [budi], waypoints: [Fixtures.startPoint, Fixtures.checkpoint])

        let arrival = TripMapArrival.Check(state, myParticipantID: Fixtures.budiID, at: Fixtures.now)

        #expect(arrival.hasArrived == false)
        #expect(arrival.everyoneHasArrived == false)
    }
}
