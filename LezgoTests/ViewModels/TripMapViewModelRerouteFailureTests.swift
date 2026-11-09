//
//  TripMapViewModelRerouteFailureTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// "Couldn't update the route. Trying again." on the leader's phone (`specs/UserStories.md` → US-06).
struct TripMapViewModelRerouteFailureTests {
    private typealias Fixtures = TripMapFixtures

    /// About 150 m north of the start, away from the route.
    private static let offRoute = Coordinate(
        latitude: Fixtures.startPoint.coordinate.latitude + 0.00136,
        longitude: Fixtures.startPoint.coordinate.longitude
    )

    private func State(secondsAgo: Double) -> TripState {
        var agus = Fixtures.Car(id: Fixtures.agusID, name: "Agus", lastSeenSecondsAgo: secondsAgo)
        agus.coordinate = Self.offRoute
        return Fixtures.State(cars: [agus, Fixtures.Car(id: Fixtures.budiID, name: "Budi")])
    }

    @Test func AFailedRerouteIsReportedOnTheLeadersPhone() async throws {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: [State(secondsAgo: 10), State(secondsAgo: 4)]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            directionsService: MockDirectionsService(results: [.failure(.init())]),
            clock: { Fixtures.now }
        )

        // `Start()` returns once the reroute has handled every state, so its result is known here.
        await viewModel.Start()

        let reroute = try #require(viewModel.reroute)
        #expect(reroute.hasFailed)
        #expect(viewModel.noticeBanner == .rerouteFailed)
    }
}
