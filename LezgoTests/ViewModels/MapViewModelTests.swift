//
//  MapViewModelTests.swift
//  LezgoTests
//
//  Created by Farrell Sudjatmiko on 28/10/26.
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import Lezgo

@MainActor
struct MapViewModelTests {
    @Test func InitialStateHasDefaults() {
        let viewModel = MapViewModel()

        #expect(viewModel.startPoint == nil)
        #expect(viewModel.destinations.isEmpty)
        #expect(viewModel.routeLegs.isEmpty)
        #expect(viewModel.selectedPolylines.isEmpty)
        #expect(viewModel.totalDistance == 0)
        #expect(viewModel.totalDuration == 0)
        #expect(viewModel.combinedPolyline == nil)
        #expect(!viewModel.hasRoute)
        #expect(!viewModel.isLoadingRoute)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.activeSelectionSheet == nil)
        #expect(viewModel.searchQuery.isEmpty)
    }

    @Test func OnAppearOpensDestinationSelectionWhenEmpty() {
        let viewModel = MapViewModel()

        viewModel.onAppear()

        #expect(viewModel.activeSelectionSheet == .destination(index: 0))
    }

    @Test func OnAppearDoesNotOverrideDestinationSelectionWhenNotEmpty() {
        let viewModel = MapViewModel()
        let point = RoutePoint(
            name: "Dest",
            subtitle: "Sub",
            coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        )
        viewModel.destinations = [point]

        viewModel.onAppear()

        #expect(viewModel.activeSelectionSheet == nil)
    }

    @Test func AddDestinationSetsActiveSheetToNextIndex() {
        let viewModel = MapViewModel()
        #expect(viewModel.destinations.isEmpty)

        viewModel.addDestination()
        #expect(viewModel.activeSelectionSheet == .destination(index: 0))

        let point = RoutePoint(
            name: "Dest 1",
            subtitle: "Sub 1",
            coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        )
        viewModel.destinations.append(point)

        viewModel.addDestination()
        #expect(viewModel.activeSelectionSheet == .destination(index: 1))
    }

    @Test func RemoveDestinationRemovesItemAtValidIndex() {
        let viewModel = MapViewModel()
        let coordA = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let coordB = CLLocationCoordinate2D(latitude: 1, longitude: 1)
        let point1 = RoutePoint(name: "A", subtitle: "Sub A", coordinate: coordA)
        let point2 = RoutePoint(name: "B", subtitle: "Sub B", coordinate: coordB)
        viewModel.destinations = [point1, point2]

        viewModel.removeDestination(at: 0)

        #expect(viewModel.destinations.count == 1)
        #expect(viewModel.destinations.first?.name == "B")
    }

    @Test func RemoveDestinationIgnoresInvalidIndex() {
        let viewModel = MapViewModel()
        let coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let point = RoutePoint(name: "A", subtitle: "Sub A", coordinate: coord)
        viewModel.destinations = [point]

        viewModel.removeDestination(at: 5)

        #expect(viewModel.destinations.count == 1)
    }

    @Test func MoveDestinationReordersItems() {
        let viewModel = MapViewModel()
        let coordA = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let coordB = CLLocationCoordinate2D(latitude: 1, longitude: 1)
        let coordC = CLLocationCoordinate2D(latitude: 2, longitude: 2)
        let point1 = RoutePoint(name: "A", subtitle: "Sub A", coordinate: coordA)
        let point2 = RoutePoint(name: "B", subtitle: "Sub B", coordinate: coordB)
        let point3 = RoutePoint(name: "C", subtitle: "Sub C", coordinate: coordC)
        viewModel.destinations = [point1, point2, point3]

        viewModel.moveDestination(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(viewModel.destinations.map(\.name) == ["B", "C", "A"])
    }

    @Test func LocationServiceCallbackSetsStartPointWhenNil() {
        let viewModel = MapViewModel()
        let coord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)

        viewModel.locationService.onFirstLocationFound?(coord)

        #expect(viewModel.startPoint != nil)
        #expect(viewModel.startPoint?.name == "Current Location")
        #expect(viewModel.startPoint?.coordinate.latitude == coord.latitude)
        #expect(viewModel.startPoint?.coordinate.longitude == coord.longitude)
    }

    @Test func LocationServiceCallbackDoesNotOverrideExistingStartPoint() {
        let viewModel = MapViewModel()
        let initialCoord = CLLocationCoordinate2D(latitude: -6.1, longitude: 106.7)
        let initialPoint = RoutePoint(name: "Custom", subtitle: "Custom Sub", coordinate: initialCoord)
        viewModel.startPoint = initialPoint

        let newCoord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        viewModel.locationService.onFirstLocationFound?(newCoord)

        #expect(viewModel.startPoint?.name == "Custom")
        #expect(viewModel.startPoint?.coordinate.latitude == initialCoord.latitude)
    }

    @Test func SelectCurrentLocationAsStartSetsPointAndClosesSearch() {
        let viewModel = MapViewModel()
        let currentCoord = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        let manager = CLLocationManager()
        let loc = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
        viewModel.locationService.locationManager(manager, didUpdateLocations: [loc])

        viewModel.activeSelectionSheet = .start
        viewModel.searchQuery = "Searching..."

        viewModel.selectCurrentLocationAsStart()

        #expect(viewModel.startPoint?.coordinate.latitude == currentCoord.latitude)
        #expect(viewModel.startPoint?.name == "Current Location")
        #expect(viewModel.activeSelectionSheet == nil)
        #expect(viewModel.searchQuery.isEmpty)
    }

    @Test func SelectCurrentLocationAsStartDoesNothingWhenNoUserLocation() {
        let viewModel = MapViewModel()
        viewModel.activeSelectionSheet = .start

        viewModel.selectCurrentLocationAsStart()

        #expect(viewModel.startPoint == nil)
        #expect(viewModel.activeSelectionSheet == .start)
    }

    @Test func FindRouteWithFewerThanTwoPointsClearsRouteLegs() {
        let viewModel = MapViewModel()
        let dummyLeg = RouteLeg(
            legIndex: 0,
            fromName: "A",
            toName: "B",
            routes: [MKRoute()]
        )
        viewModel.routeLegs = [dummyLeg]

        // 0 points
        viewModel.findRoute()
        #expect(viewModel.routeLegs.isEmpty)

        // 1 point
        viewModel.routeLegs = [dummyLeg]
        viewModel.startPoint = RoutePoint(
            name: "A",
            subtitle: "Sub A",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        viewModel.findRoute()
        #expect(viewModel.routeLegs.isEmpty)
    }

    @Test func SelectLegRouteUpdatesSelectedRouteIndex() {
        let viewModel = MapViewModel()
        let leg = RouteLeg(
            legIndex: 0,
            fromName: "A",
            toName: "B",
            routes: [MKRoute(), MKRoute()],
            selectedRouteIndex: 0
        )
        viewModel.routeLegs = [leg]

        viewModel.selectLegRoute(legIndex: 0, routeIndex: 1)

        #expect(viewModel.routeLegs[0].selectedRouteIndex == 1)
    }

    @Test func SelectLegRouteIgnoresInvalidIndices() {
        let viewModel = MapViewModel()
        let leg = RouteLeg(
            legIndex: 0,
            fromName: "A",
            toName: "B",
            routes: [MKRoute()],
            selectedRouteIndex: 0
        )
        viewModel.routeLegs = [leg]

        // Invalid leg index
        viewModel.selectLegRoute(legIndex: 2, routeIndex: 0)
        #expect(viewModel.routeLegs[0].selectedRouteIndex == 0)

        // Invalid route index
        viewModel.selectLegRoute(legIndex: 0, routeIndex: 5)
        #expect(viewModel.routeLegs[0].selectedRouteIndex == 0)
    }
}
