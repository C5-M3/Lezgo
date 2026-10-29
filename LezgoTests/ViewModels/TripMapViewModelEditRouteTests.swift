//
//  TripMapViewModelEditRouteTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 29/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Opening and closing Edit Route from the trip map (`specs/UserStories.md` → US-06, "Route changes").
struct TripMapViewModelEditRouteTests {
    private typealias Fixtures = TripMapFixtures

    /// Where Agus's car is in these tests.
    private static let agusPosition = Coordinate(latitude: -7.2650, longitude: 112.7300)

    private func MakeViewModel(me: UUID = Fixtures.agusID, service: MockTripService) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
    }

    private func State(
        leaderID: UUID = Fixtures.agusID,
        agusHasPosition: Bool = true,
        status: TripStatus = .inTrip,
        currentWaypointIndex: Int = 1
    ) -> TripState {
        var agus = Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        agus.coordinate = agusHasPosition ? Self.agusPosition : nil
        let budi = Fixtures.Car(id: Fixtures.budiID, name: "Budi")
        var state = Fixtures.State(cars: [agus, budi], status: status, currentWaypointIndex: currentWaypointIndex)
        state.trip.leaderParticipantID = leaderID
        return state
    }

    // MARK: Opening

    @Test func LeaderOpensEditRouteFromTheirPositionThroughWhatIsLeft() async throws {
        let viewModel = MakeViewModel(service: MockTripService(states: [State()]))
        await viewModel.Start()

        viewModel.RequestEditRoute()

        let editRoute = try #require(viewModel.editRoute)
        #expect(editRoute.startingWaypoints.map(\.kind) == [.start, .checkpoint, .destination])
        #expect(editRoute.startingWaypoints.map(\.name) == ["Current Location", "Ciputra World", "Pakuwon mall"])
        #expect(editRoute.startingWaypoints.first?.coordinate == Self.agusPosition)
    }

    @Test func VisitedCheckpointIsNotOfferedAgain() async throws {
        let viewModel = MakeViewModel(service: MockTripService(states: [State(currentWaypointIndex: 2)]))
        await viewModel.Start()

        viewModel.RequestEditRoute()

        let editRoute = try #require(viewModel.editRoute)
        #expect(editRoute.startingWaypoints.map(\.name) == ["Current Location", "Pakuwon mall"])
    }

    @Test func MemberCannotOpenEditRoute() async {
        let viewModel = MakeViewModel(me: Fixtures.budiID, service: MockTripService(states: [State()]))
        await viewModel.Start()

        viewModel.RequestEditRoute()

        #expect(viewModel.editRoute == nil)
    }

    @Test func EditRouteWaitsForTheLeadersFirstPosition() async {
        let viewModel = MakeViewModel(service: MockTripService(states: [State(agusHasPosition: false)]))
        await viewModel.Start()

        viewModel.RequestEditRoute()

        #expect(viewModel.editRoute == nil)
    }

    @Test func LeaderCanEditTheRouteOnceTheirPositionIsKnown() async {
        let waiting = MakeViewModel(service: MockTripService(states: [State(agusHasPosition: false)]))
        let ready = MakeViewModel(service: MockTripService(states: [State()]))
        let member = MakeViewModel(me: Fixtures.budiID, service: MockTripService(states: [State()]))

        await waiting.Start()
        await ready.Start()
        await member.Start()

        #expect(waiting.canEditRoute == false)
        #expect(ready.canEditRoute)
        #expect(member.canEditRoute == false)
    }

    @Test func EditRouteCannotOpenBeforeTheFirstUpdate() {
        let viewModel = MakeViewModel(service: MockTripService(states: []))

        viewModel.RequestEditRoute()

        #expect(viewModel.editRoute == nil)
    }

    @Test func RepeatedTapsKeepTheSameEditRoute() async throws {
        let viewModel = MakeViewModel(service: MockTripService(states: [State()]))
        await viewModel.Start()

        viewModel.RequestEditRoute()
        let first = try #require(viewModel.editRoute)
        viewModel.RequestEditRoute()

        #expect(viewModel.editRoute === first)
    }

    // MARK: Closing

    @Test func CancelClosesEditRouteWithoutSaving() async {
        let service = MockTripService(states: [State()])
        let viewModel = MakeViewModel(service: service)
        await viewModel.Start()
        viewModel.RequestEditRoute()

        viewModel.CloseEditRoute()

        #expect(viewModel.editRoute == nil)
        #expect(service.savedRoutes.isEmpty)
    }

    @Test func EditRouteClosesWhenTheLeadIsHandedOver() async {
        let service = MockTripService(states: [State(), State(leaderID: Fixtures.budiID)])
        let viewModel = MakeViewModel(service: service)
        service.beforeEachState = { index in
            if index == 1 { viewModel.RequestEditRoute() }
        }

        await viewModel.Start()

        #expect(viewModel.editRoute == nil)
    }

    @Test func EditRouteStaysOpenWhileTheLeaderDrives() async {
        let service = MockTripService(states: [State(), State()])
        let viewModel = MakeViewModel(service: service)
        service.beforeEachState = { index in
            if index == 1 { viewModel.RequestEditRoute() }
        }

        await viewModel.Start()

        #expect(viewModel.editRoute != nil)
    }

    @Test func EditRouteClosesWhenTheTripEnds() async {
        let service = MockTripService(states: [State(), State(status: .ended)])
        let viewModel = MakeViewModel(service: service)
        service.beforeEachState = { index in
            if index == 1 { viewModel.RequestEditRoute() }
        }

        await viewModel.Start()

        #expect(viewModel.editRoute == nil)
    }
}
