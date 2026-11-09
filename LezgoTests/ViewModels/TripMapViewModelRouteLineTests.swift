//
//  TripMapViewModelRouteLineTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The route line is the same on every phone: it starts at the last car on the group's road, so a car in the middle
/// never cuts it off for the cars behind (`specs/UserStories.md` → US-06, "Map").
struct TripMapViewModelRouteLineTests {
    private typealias Fixtures = TripMapFixtures

    /// The route runs straight south. Agus leads at -7.2800, Budi is in the middle at -7.2700, Citra is last.
    private static let north = Coordinate(latitude: -7.2600, longitude: 112.7300)
    private static let south = Coordinate(latitude: -7.2900, longitude: 112.7300)
    private static let citraOnRoad = Coordinate(latitude: -7.2650, longitude: 112.7300)
    /// About 330 m east of the route, with a way back joining it at -7.2680.
    private static let citraLost = Coordinate(latitude: -7.2620, longitude: 112.7330)
    private static let rejoin = Coordinate(latitude: -7.2680, longitude: 112.7300)

    private func Trip(
        citra: Coordinate = citraOnRoad,
        citraSecondsAgo: Double = 1,
        citraWayBack: [Coordinate] = []
    ) -> TripState {
        var citraCar = Fixtures.Car(id: Fixtures.citraID, name: "Citra", lastSeenSecondsAgo: citraSecondsAgo)
        citraCar.coordinate = citra
        citraCar.wayBack = citraWayBack
        var state = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus", latitude: -7.2800),
            Fixtures.Car(id: Fixtures.budiID, name: "Budi", latitude: -7.2700),
            citraCar
        ])
        state.route?.polyline = [Self.north, Self.south]
        return state
    }

    /// Whether the line starts within a metre of `point`: the start is worked out on the line, so it can be a hair off.
    private func StartsAt(_ line: [Coordinate], _ point: Coordinate) -> Bool {
        line.first.map { $0.Distance(to: point) < 1 } ?? false
    }

    private func OpenMap(_ state: TripState, me: UUID = Fixtures.budiID) async -> TripMapViewModel {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: MockTripService(states: [state]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            directionsService: MockDirectionsService(results: []),
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        return viewModel
    }

    @Test func LineStartsAtTheLastCarNotAtMine() async {
        let viewModel = await OpenMap(Trip())

        #expect(StartsAt(viewModel.routeLine, Self.citraOnRoad))
        #expect(viewModel.routeLine.last == Self.south)
    }

    @Test func LeaderSeesTheSameLine() async {
        let viewModel = await OpenMap(Trip(), me: Fixtures.agusID)

        #expect(StartsAt(viewModel.routeLine, Self.citraOnRoad))
    }

    @Test func CarOffTheRoadCountsWhereItsWayBackJoins() async {
        let viewModel = await OpenMap(Trip(citra: Self.citraLost, citraWayBack: [Self.citraLost, Self.rejoin]))

        #expect(StartsAt(viewModel.routeLine, Self.rejoin))
    }

    @Test func OfflineCarDoesNotHoldTheLineBack() async {
        // Its last position is out of date: the line starts at the last car still sending one, Budi.
        let viewModel = await OpenMap(Trip(citraSecondsAgo: 300))

        #expect(StartsAt(viewModel.routeLine, Coordinate(latitude: -7.2700, longitude: 112.7300)))
    }

    @Test func EveryPhoneSeesAnotherCarsWayBackInItsRobotColour() async {
        let viewModel = await OpenMap(Trip(citra: Self.citraLost, citraWayBack: [Self.citraLost, Self.rejoin]))

        #expect(viewModel.wayBacks.map(\.id) == [Fixtures.citraID])
        #expect(viewModel.wayBacks.first?.carColor == .pink)
        #expect(viewModel.wayBacks.first?.path.last == Self.rejoin)
    }

    @Test func MyOwnWayBackIsNotDrawnAsAnotherCars() async {
        let viewModel = await OpenMap(
            Trip(citra: Self.citraLost, citraWayBack: [Self.citraLost, Self.rejoin]),
            me: Fixtures.citraID
        )

        #expect(viewModel.wayBacks.isEmpty)
    }
}
