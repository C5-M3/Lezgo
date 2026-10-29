//
//  MapViewModelTripPlanTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 29/10/26.
//

import CoreLocation
import MapKit
import Testing
@testable import Lezgo

/// The planner opened on the road for Edit Route, and the route it hands back
/// (`specs/UserStories.md` → US-06, "Route changes").
@MainActor
struct MapViewModelTripPlanTests {
    private typealias Fixtures = TripMapFixtures

    private static let remainingRoute = [
        PlannedWaypoint(kind: .start, name: "Current Location", coordinate: Fixtures.startPoint.coordinate),
        PlannedWaypoint(kind: .checkpoint, name: "Ciputra World", coordinate: Fixtures.checkpoint.coordinate),
        PlannedWaypoint(kind: .destination, name: "Pakuwon mall", coordinate: Fixtures.destination.coordinate)
    ]

    /// MapKit has no public way to build a route, so the test gives one its own line.
    private final class FakeRoute: MKRoute {
        private let line: MKPolyline

        init(through coordinates: [Coordinate]) {
            let points = coordinates.map(\.locationCoordinate)
            line = MKPolyline(coordinates: points, count: points.count)
            super.init()
        }

        override var polyline: MKPolyline { line }
    }

    private func Leg(_ index: Int, through coordinates: [Coordinate]) -> RouteLeg {
        RouteLeg(legIndex: index, fromName: "", toName: "", routes: [FakeRoute(through: coordinates)])
    }

    @Test func OpensWithTheGivenWaypoints() {
        let viewModel = MapViewModel(startingWaypoints: Self.remainingRoute)

        #expect(viewModel.startPoint?.name == "Current Location")
        #expect(viewModel.startPoint?.coordinate.latitude == Fixtures.startPoint.coordinate.latitude)
        #expect(viewModel.destinations.map(\.name) == ["Ciputra World", "Pakuwon mall"])
    }

    @Test func FirstGpsFixKeepsTheGivenStartPoint() {
        let viewModel = MapViewModel(startingWaypoints: Self.remainingRoute)

        viewModel.locationService.onFirstLocationFound?(Fixtures.destination.coordinate.locationCoordinate)

        #expect(viewModel.startPoint?.coordinate.latitude == Fixtures.startPoint.coordinate.latitude)
    }

    @Test func OpeningWithWaypointsDoesNotAskForADestination() {
        let viewModel = MapViewModel(startingWaypoints: Self.remainingRoute)

        viewModel.onAppear()

        #expect(viewModel.activeSelectionSheet == nil)
    }

    @Test func RouteBecomesATripPlan() throws {
        let viewModel = MapViewModel(startingWaypoints: Self.remainingRoute)
        let start = Fixtures.startPoint.coordinate
        let checkpoint = Fixtures.checkpoint.coordinate
        let destination = Fixtures.destination.coordinate
        viewModel.routeLegs = [Leg(0, through: [start, checkpoint]), Leg(1, through: [checkpoint, destination])]

        let plan = try #require(viewModel.MakeTripPlan())

        #expect(plan.waypoints == Self.remainingRoute)
        #expect(plan.isValid)
        #expect(plan.polyline.count == 4)
        #expect(plan.polyline.first == start)
        #expect(plan.polyline.last == destination)
    }

    @Test func OneStopIsTheDestination() throws {
        let viewModel = MapViewModel(startingWaypoints: [Self.remainingRoute[0], Self.remainingRoute[2]])
        viewModel.routeLegs = [Leg(0, through: [Fixtures.startPoint.coordinate, Fixtures.destination.coordinate])]

        let plan = try #require(viewModel.MakeTripPlan())

        #expect(plan.waypoints.map(\.kind) == [.start, .destination])
    }

    @Test func NoRouteYetGivesNoPlan() {
        let viewModel = MapViewModel(startingWaypoints: Self.remainingRoute)

        #expect(viewModel.MakeTripPlan() == nil)
    }

    @Test func RouteStillCalculatingGivesNoPlan() {
        let viewModel = MapViewModel(startingWaypoints: Self.remainingRoute)
        viewModel.routeLegs = [Leg(0, through: [Fixtures.startPoint.coordinate, Fixtures.destination.coordinate])]
        viewModel.isLoadingRoute = true

        #expect(viewModel.MakeTripPlan() == nil)
    }

    @Test func NoDestinationGivesNoPlan() {
        let viewModel = MapViewModel(startingWaypoints: Self.remainingRoute)
        viewModel.routeLegs = [Leg(0, through: [Fixtures.startPoint.coordinate, Fixtures.destination.coordinate])]
        viewModel.destinations = []

        #expect(viewModel.MakeTripPlan() == nil)
    }
}
