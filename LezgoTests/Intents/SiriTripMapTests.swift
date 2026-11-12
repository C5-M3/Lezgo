//
//  SiriTripMapTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Testing
@testable import Lezgo

/// "Join a trip" and "Create a trip" from Siri change nothing while this phone already has a trip
/// (`specs/UserStories.md` → US-08).
@MainActor
struct SiriTripMapTests {
    @Test func NoTripOnThePhoneLetsSiriPlanOne() {
        #expect(SiriTripMap.HasTripOnThisPhone(
            activeTripMap: ActiveTripMap(),
            storage: FakeActiveTripStorage()
        ) == false)
    }

    @Test func SavedTripOrDraftCounts() {
        let session = TripSession(myParticipantID: TripFixtures.budiID, state: TripMapFixtures.State())
        let storage = FakeActiveTripStorage(initial: .From(session: session))

        #expect(SiriTripMap.HasTripOnThisPhone(activeTripMap: ActiveTripMap(), storage: storage))
    }

    @Test func OpenTripMapCounts() {
        let activeTripMap = ActiveTripMap()
        activeTripMap.Show(TripMapViewModel(
            tripID: TripMapFixtures.tripID,
            myParticipantID: TripMapFixtures.budiID,
            tripService: MockTripService(states: []),
            navigator: MockTripMapNavigator(results: []),
            streetNameService: MockStreetNameService()
        ))

        #expect(SiriTripMap.HasTripOnThisPhone(activeTripMap: activeTripMap, storage: FakeActiveTripStorage()))
    }
}
