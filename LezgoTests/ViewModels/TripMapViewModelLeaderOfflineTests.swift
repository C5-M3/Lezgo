//
//  TripMapViewModelLeaderOfflineTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// A leader who stays offline is only shown as offline: the group stays on the same route and keeps the same leader
/// (`specs/UserStories.md` → US-06, "Leader offline").
struct TripMapViewModelLeaderOfflineTests {
    private typealias Fixtures = TripMapFixtures

    private func State(leaderSecondsAgo: Double, cars extraCars: [Participant] = []) -> TripState {
        Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus", lastSeenSecondsAgo: leaderSecondsAgo),
            Fixtures.Car(id: Fixtures.budiID, name: "Budi")
        ] + extraCars)
    }

    private func Started(states: [TripState]) async -> TripMapViewModel {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: states),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        return viewModel
    }

    @Test(arguments: [121.0, 300, 3_600])
    func AnOfflineLeaderIsShownAndTheRouteStays(secondsAgo: Double) async {
        let online = await Started(states: [State(leaderSecondsAgo: 1)])
        let offline = await Started(states: [State(leaderSecondsAgo: secondsAgo)])

        #expect(offline.noticeBanner == .leaderOffline(name: "Agus"))
        #expect(offline.route == online.route)
        #expect(offline.destinationName == online.destinationName)
        #expect(offline.guidance == online.guidance)
    }

    @Test func TheLeaderStaysTheLeaderEvenWithOneMemberLeft() async {
        let viewModel = await Started(states: [State(leaderSecondsAgo: 3_600)])

        #expect(viewModel.state?.trip.leaderParticipantID == Fixtures.agusID)
        #expect(viewModel.isLeader == false)
    }
}
