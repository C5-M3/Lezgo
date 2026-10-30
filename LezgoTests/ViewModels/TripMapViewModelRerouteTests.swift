//
//  TripMapViewModelRerouteTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The automatic reroute when the leader leaves the route, and members switching to the new route
/// (`specs/UserStories.md` → US-06, "Route changes").
struct TripMapViewModelRerouteTests {
    private typealias Fixtures = TripMapFixtures

    /// The start of the route.
    private static let onRoute = Fixtures.startPoint.coordinate
    /// About 150 m north of the start, away from the route.
    private static let offRoute = Coordinate(latitude: onRoute.latitude + 0.00136, longitude: onRoute.longitude)
    /// The road path the directions service returns.
    private static let newPath = [offRoute, Fixtures.checkpoint.coordinate, Fixtures.destination.coordinate]

    private func MakeViewModel(
        me: UUID = Fixtures.agusID,
        service: MockTripService,
        directions: MockDirectionsService = MockDirectionsService(results: [.success(newPath)])
    ) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            directionsService: directions,
            clock: { Fixtures.now }
        )
    }

    /// The trip with Agus at `agus` and Budi at `budi`, each phone's reading `secondsAgo` before now.
    private func State(
        agus: Coordinate = onRoute,
        budi: Coordinate = onRoute,
        secondsAgo: Double = 1,
        routeVersion: Int = 1,
        polyline: [Coordinate]? = nil,
        currentWaypointIndex: Int = 1
    ) -> TripState {
        var agusCar = Fixtures.Car(id: Fixtures.agusID, name: "Agus", lastSeenSecondsAgo: secondsAgo)
        agusCar.coordinate = agus
        var budiCar = Fixtures.Car(id: Fixtures.budiID, name: "Budi", lastSeenSecondsAgo: secondsAgo)
        budiCar.coordinate = budi
        var state = Fixtures.State(cars: [agusCar, budiCar], currentWaypointIndex: currentWaypointIndex)
        state.trip.routeVersion = routeVersion
        state.route?.version = routeVersion
        if let polyline {
            state.route?.polyline = polyline
        }
        return state
    }

    // MARK: Leader leaves the route

    @Test func LeaderOffTheRouteFor15SecondsSavesANewRouteThroughTheCheckpoint() async throws {
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 30),
            State(agus: Self.offRoute, secondsAgo: 14)
        ])
        let directions = MockDirectionsService(results: [.success(Self.newPath)])
        let viewModel = MakeViewModel(service: service, directions: directions)

        await viewModel.Start()

        #expect(directions.requestedPoints == [
            [Self.offRoute, Fixtures.checkpoint.coordinate, Fixtures.destination.coordinate]
        ])
        let plan = try #require(service.savedRoutes.first)
        #expect(service.savedRoutes.count == 1)
        #expect(plan.waypoints.map(\.kind) == [.start, .checkpoint, .destination])
        #expect(plan.waypoints.map(\.name) == ["Current Location", "Ciputra World", "Pakuwon mall"])
        #expect(plan.waypoints.first?.coordinate == Self.offRoute)
        #expect(plan.polyline == Self.newPath)
    }

    @Test func GPSJumpOfAFewSecondsDoesNotReroute() async {
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 4),
            State(agus: Self.offRoute, secondsAgo: 1),
            State(agus: Self.onRoute, secondsAgo: 0)
        ])
        let directions = MockDirectionsService(results: [.success(Self.newPath)])
        let viewModel = MakeViewModel(service: service, directions: directions)

        await viewModel.Start()

        #expect(directions.requestedPoints.isEmpty)
        #expect(service.savedRoutes.isEmpty)
    }

    @Test func VisitedCheckpointIsLeftOutOfTheNewRoute() async {
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 30, currentWaypointIndex: 2),
            State(agus: Self.offRoute, secondsAgo: 14, currentWaypointIndex: 2)
        ])
        let directions = MockDirectionsService(results: [.success(Self.newPath)])
        let viewModel = MakeViewModel(service: service, directions: directions)

        await viewModel.Start()

        #expect(directions.requestedPoints == [[Self.offRoute, Fixtures.destination.coordinate]])
        #expect(service.savedRoutes.first?.waypoints.map(\.kind) == [.start, .destination])
    }

    @Test func LeaderStillOffTheOldRouteAsksOnlyOnce() async {
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 30),
            State(agus: Self.offRoute, secondsAgo: 14),
            State(agus: Self.offRoute, secondsAgo: 13),
            State(agus: Self.offRoute, secondsAgo: 12)
        ])
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(service.savedRoutes.count == 1)
    }

    @Test func LeaderLeavesTheNewRouteTooAndGetsAnotherOne() async {
        let farOff = Coordinate(latitude: Self.offRoute.latitude + 0.00136, longitude: Self.offRoute.longitude)
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 60),
            State(agus: Self.offRoute, secondsAgo: 44),
            State(agus: farOff, secondsAgo: 30, routeVersion: 2, polyline: Self.newPath),
            State(agus: farOff, secondsAgo: 14, routeVersion: 2, polyline: Self.newPath)
        ])
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(service.savedRoutes.count == 2)
        #expect(service.savedRoutes.last?.waypoints.first?.coordinate == farOff)
    }

    @Test func MemberOffTheRouteNeverReroutes() async {
        let service = MockTripService(states: [
            State(budi: Self.offRoute, secondsAgo: 30),
            State(budi: Self.offRoute, secondsAgo: 14)
        ])
        let directions = MockDirectionsService(results: [.success(Self.newPath)])
        let viewModel = MakeViewModel(me: Fixtures.budiID, service: service, directions: directions)

        await viewModel.Start()

        #expect(directions.requestedPoints.isEmpty)
        #expect(service.savedRoutes.isEmpty)
    }

    @Test func MemberSeesTheLeaderOffTheRouteButNeverReroutes() async {
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 30),
            State(agus: Self.offRoute, secondsAgo: 14),
            State(agus: Self.offRoute, secondsAgo: 1)
        ])
        let directions = MockDirectionsService(results: [.success(Self.newPath)])
        let viewModel = MakeViewModel(me: Fixtures.budiID, service: service, directions: directions)

        await viewModel.Start()

        // Only the leader's phone reroutes, so the members never ask for directions or save a route.
        #expect(directions.requestedPoints.isEmpty)
        #expect(service.savedRoutes.isEmpty)
    }

    // MARK: Slow network

    @Test func SlowRerouteDoesNotHoldBackTheNextTripUpdates() async throws {
        let lastUpdate = State(agus: Self.offRoute, budi: Self.offRoute, secondsAgo: 0)
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 30),
            State(agus: Self.offRoute, secondsAgo: 14),
            lastUpdate
        ])
        let directions = MockDirectionsService(results: [.success(Self.newPath)])
        directions.holdsRequests = true
        let viewModel = MakeViewModel(service: service, directions: directions)
        let open = Task { await viewModel.Start() }

        // Waits for the update, not for a fixed time; gives up after a while so a blocked map fails instead of hanging.
        for _ in 0..<1_000 where viewModel.state != lastUpdate {
            await Task.yield()
        }

        #expect(directions.requestedPoints.count == 1)
        #expect(viewModel.state == lastUpdate)
        directions.ReleaseRequests()
        await open.value
        #expect(service.savedRoutes.count == 1)
    }

    // MARK: Edit Route

    @Test func NoRerouteWhileTheLeaderEditsTheRoute() async {
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 30),
            State(agus: Self.offRoute, secondsAgo: 14)
        ])
        let directions = MockDirectionsService(results: [.success(Self.newPath)])
        let viewModel = MakeViewModel(service: service, directions: directions)
        service.beforeEachState = { index in
            if index == 1 { viewModel.RequestEditRoute() }
        }

        await viewModel.Start()

        #expect(viewModel.editRoute != nil)
        #expect(directions.requestedPoints.isEmpty)
        #expect(service.savedRoutes.isEmpty)
    }

    @Test func RerouteOnItsWayWhenEditRouteOpensIsDropped() async {
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 30),
            State(agus: Self.offRoute, secondsAgo: 14)
        ])
        let directions = MockDirectionsService(results: [.success(Self.newPath)])
        directions.holdsRequests = true
        let viewModel = MakeViewModel(service: service, directions: directions)
        let open = Task { await viewModel.Start() }
        for _ in 0..<1_000 where directions.requestedPoints.isEmpty {
            await Task.yield()
        }

        // The leader opens Edit Route, and even closes it again, before the directions request returns.
        viewModel.RequestEditRoute()
        viewModel.CloseEditRoute()
        directions.ReleaseRequests()
        await open.value

        #expect(directions.requestedPoints.count == 1)
        #expect(service.savedRoutes.isEmpty)
    }

    // MARK: No network

    @Test func FailedSaveIsTriedAgainAfter30Seconds() async {
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 60),
            State(agus: Self.offRoute, secondsAgo: 44),
            State(agus: Self.offRoute, secondsAgo: 20),
            State(agus: Self.offRoute, secondsAgo: 10)
        ])
        service.nextSaveRouteFailure = .noNetwork
        let directions = MockDirectionsService(results: [.success(Self.newPath)])
        let viewModel = MakeViewModel(service: service, directions: directions)

        await viewModel.Start()

        // Asked at 44 s ago (failed to save), not again at 20 s ago, again at 10 s ago (34 s later).
        #expect(directions.requestedPoints.count == 2)
        #expect(service.savedRoutes.count == 1)
    }

    @Test func NoRouteFoundKeepsTheOldRouteAndTriesAgainAfter30Seconds() async {
        let service = MockTripService(states: [
            State(agus: Self.offRoute, secondsAgo: 60),
            State(agus: Self.offRoute, secondsAgo: 44),
            State(agus: Self.offRoute, secondsAgo: 20),
            State(agus: Self.offRoute, secondsAgo: 10)
        ])
        let directions = MockDirectionsService(results: [.failure(.init()), .success(Self.newPath)])
        let viewModel = MakeViewModel(service: service, directions: directions)

        await viewModel.Start()

        #expect(directions.requestedPoints.count == 2)
        #expect(service.savedRoutes.count == 1)
        #expect(viewModel.route == [Fixtures.startPoint, Fixtures.checkpoint, Fixtures.destination].map(\.coordinate))
    }

    // MARK: Members switch to the new route

    @Test func MemberSwitchesToTheNewRouteAndNeverGoesBack() async {
        let service = MockTripService(states: [
            State(routeVersion: 2, polyline: Self.newPath),
            State(routeVersion: 1)
        ])
        let viewModel = MakeViewModel(me: Fixtures.budiID, service: service)

        await viewModel.Start()

        #expect(viewModel.route == Self.newPath)
        #expect(viewModel.state?.trip.routeVersion == 2)
    }
}
