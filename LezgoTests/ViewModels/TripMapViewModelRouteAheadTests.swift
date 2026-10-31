//
//  TripMapViewModelRouteAheadTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The map draws only what is still ahead, as in Apple Maps: the route from this phone's car on, and the stops not
/// passed yet. Budi, a member, uses this phone.
struct TripMapViewModelRouteAheadTests {
    private typealias Fixtures = TripMapFixtures

    private func OpenMap(_ state: TripState) async -> TripMapViewModel {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: [state]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        return viewModel
    }

    @Test func DrivenPartOfTheRouteIsNotDrawn() async {
        var budi = Fixtures.Car(id: Fixtures.budiID, name: "Budi")
        budi.coordinate = Fixtures.checkpoint.coordinate
        let state = Fixtures.State(cars: [Fixtures.Car(id: Fixtures.agusID, name: "Agus"), budi])

        let viewModel = await OpenMap(state)

        #expect(viewModel.routeAhead.first == Fixtures.checkpoint.coordinate)
        #expect(viewModel.routeAhead.last == Fixtures.destination.coordinate)
        #expect(viewModel.routeAhead.contains(Fixtures.startPoint.coordinate) == false)
    }

    @Test func WholeRouteIsDrawnUntilMyCarIsKnown() async {
        var budi = Fixtures.Car(id: Fixtures.budiID, name: "Budi")
        budi.coordinate = nil
        let state = Fixtures.State(cars: [Fixtures.Car(id: Fixtures.agusID, name: "Agus"), budi])

        let viewModel = await OpenMap(state)

        #expect(viewModel.routeAhead == viewModel.route)
    }

    @Test func StartPointIsNotPinnedOnTheRoad() async {
        // A reroute starts the new route at the leader's position, named "Current Location"; it is never a stop.
        let viewModel = await OpenMap(Fixtures.State(currentWaypointIndex: 1))

        #expect(viewModel.upcomingWaypoints.map(\.name) == ["Ciputra World", "Pakuwon mall"])
    }

    @Test func PassedCheckpointIsNotPinned() async {
        let viewModel = await OpenMap(Fixtures.State(currentWaypointIndex: 2))

        #expect(viewModel.upcomingWaypoints.map(\.name) == ["Pakuwon mall"])
    }
}
