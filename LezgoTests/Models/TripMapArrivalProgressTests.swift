//
//  TripMapArrivalProgressTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Who has arrived and in what order, for the robots on the top card (`specs/UserStories.md` → US-07, "Arrive").
struct TripMapArrivalProgressTests {
    private typealias Fixtures = TripMapFixtures

    private func Near(_ id: UUID, _ name: String, metres: Double = 5, lastSeenSecondsAgo: Double = 1) -> Participant {
        Fixtures.CarNearDestination(id: id, name: name, metres: metres, lastSeenSecondsAgo: lastSeenSecondsAgo)
    }

    private func Updated(_ order: TripMapArrivalOrder, cars: [Participant], me: UUID = Fixtures.budiID) -> [UUID] {
        var order = order
        order.Update(Fixtures.State(cars: cars), myParticipantID: me, at: Fixtures.now)
        return order.ids
    }

    @Test func OnlyCarsWithinTwentyMetresCount() {
        let ids = Updated(TripMapArrivalOrder(), cars: [
            Near(Fixtures.agusID, "Agus"),
            Near(Fixtures.budiID, "Budi", metres: 500),
            Near(Fixtures.citraID, "Citra", metres: 19)
        ])

        #expect(ids == [Fixtures.agusID, Fixtures.citraID])
    }

    @Test func TheFirstToArriveStaysFirstWhateverTheParticipantOrder() {
        var order = TripMapArrivalOrder()
        order.Update(
            Fixtures.State(cars: [
                Near(Fixtures.agusID, "Agus", metres: 500),
                Near(Fixtures.citraID, "Citra")
            ]),
            myParticipantID: Fixtures.budiID,
            at: Fixtures.now
        )

        let ids = Updated(order, cars: [Near(Fixtures.agusID, "Agus"), Near(Fixtures.citraID, "Citra")])

        #expect(ids == [Fixtures.citraID, Fixtures.agusID])
    }

    @Test func ACarThatDrivesAwayLeavesTheOrder() {
        var order = TripMapArrivalOrder()
        order.Update(
            Fixtures.State(cars: [Near(Fixtures.agusID, "Agus"), Near(Fixtures.citraID, "Citra")]),
            myParticipantID: Fixtures.budiID,
            at: Fixtures.now
        )

        let ids = Updated(order, cars: [
            Near(Fixtures.agusID, "Agus", metres: 500),
            Near(Fixtures.citraID, "Citra")
        ])

        #expect(ids == [Fixtures.citraID])
    }

    @Test func AnOfflineCarDoesNotCount() {
        let ids = Updated(TripMapArrivalOrder(), cars: [Near(Fixtures.agusID, "Agus", lastSeenSecondsAgo: 300)])

        #expect(ids.isEmpty)
    }

    @Test func MyOwnCarCountsEvenWhenThisPhoneLooksOffline() {
        let ids = Updated(TripMapArrivalOrder(), cars: [Near(Fixtures.budiID, "Budi", lastSeenSecondsAgo: 300)])

        #expect(ids == [Fixtures.budiID])
    }

    @Test func AMemberWhoExitedLeavesTheOrder() {
        var order = TripMapArrivalOrder()
        order.Update(
            Fixtures.State(cars: [Near(Fixtures.agusID, "Agus"), Near(Fixtures.citraID, "Citra")]),
            myParticipantID: Fixtures.budiID,
            at: Fixtures.now
        )

        let ids = Updated(order, cars: [Near(Fixtures.citraID, "Citra")])

        #expect(ids == [Fixtures.citraID])
    }

    @Test func ANewTripStateWithoutADestinationClearsTheOrder() {
        var order = TripMapArrivalOrder()
        order.Update(
            Fixtures.State(cars: [Near(Fixtures.agusID, "Agus")]),
            myParticipantID: Fixtures.budiID,
            at: Fixtures.now
        )

        order.Update(
            Fixtures.State(cars: [Near(Fixtures.agusID, "Agus")], waypoints: []),
            myParticipantID: Fixtures.budiID,
            at: Fixtures.now
        )

        #expect(order.ids.isEmpty)
    }
}
