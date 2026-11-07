//
//  ActiveTripMapTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The trip map open on the phone, which CarPlay mirrors (ADR 0023).
struct ActiveTripMapTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeTripMap() -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: []),
            navigator: MockTripMapNavigator(results: []),
            streetNameService: MockStreetNameService()
        )
    }

    @Test func NothingIsOpenAtFirst() {
        #expect(ActiveTripMap().tripMap == nil)
    }

    @Test func OpenedTripMapIsShown() {
        let activeTripMap = ActiveTripMap()
        let tripMap = MakeTripMap()

        activeTripMap.Show(tripMap)

        #expect(activeTripMap.tripMap === tripMap)
    }

    @Test func ClosingTheOpenTripMapClearsIt() {
        let activeTripMap = ActiveTripMap()
        let tripMap = MakeTripMap()
        activeTripMap.Show(tripMap)

        activeTripMap.Hide(tripMap)

        #expect(activeTripMap.tripMap == nil)
    }

    /// A map that opens before the old one has gone (Trip Room → map again) must not be cleared by the old one.
    @Test func ClosingAnOlderTripMapKeepsTheNewOne() {
        let activeTripMap = ActiveTripMap()
        let oldTripMap = MakeTripMap()
        let newTripMap = MakeTripMap()
        activeTripMap.Show(oldTripMap)
        activeTripMap.Show(newTripMap)

        activeTripMap.Hide(oldTripMap)

        #expect(activeTripMap.tripMap === newTripMap)
    }
}
