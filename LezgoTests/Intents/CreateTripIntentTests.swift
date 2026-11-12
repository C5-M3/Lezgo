//
//  CreateTripIntentTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Testing
@testable import Lezgo

/// "Create a trip" from Siri opens nothing while this phone already has a trip (`specs/UserStories.md` → US-08).
@MainActor
struct CreateTripIntentTests {
    @Test func NoTripOnThePhoneLetsSiriPlanOne() {
        #expect(CreateTripIntent.HasTripOnThisPhone(
            activeTripMap: ActiveTripMap(),
            storage: FakeActiveTripStorage()
        ) == false)
    }

    @Test func SavedTripOrDraftCounts() {
        let session = TripSession(myParticipantID: TripFixtures.budiID, state: TripMapFixtures.State())
        let storage = FakeActiveTripStorage(initial: .From(session: session))

        #expect(CreateTripIntent.HasTripOnThisPhone(activeTripMap: ActiveTripMap(), storage: storage))
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

        #expect(CreateTripIntent.HasTripOnThisPhone(activeTripMap: activeTripMap, storage: FakeActiveTripStorage()))
    }
}
