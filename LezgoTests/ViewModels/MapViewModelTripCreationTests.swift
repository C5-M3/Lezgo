//
//  MapViewModelTripCreationTests.swift
//  LezgoTests
//
//  Created by Farrell Sudjatmiko on 29/10/26.
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

@MainActor
struct MapViewModelTripCreationTests {
    @Test func CanCreateTripRequiresStartAndDestination() {
        let viewModel = MapViewModel()
        let start = RoutePoint(
            name: "Start",
            subtitle: "Sub",
            coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        )
        let dest = RoutePoint(
            name: "Dest",
            subtitle: "Sub",
            coordinate: CLLocationCoordinate2D(latitude: -6.3, longitude: 106.9)
        )

        // Neither
        #expect(!viewModel.canCreateTrip)
        #expect(!viewModel.isRouteComplete)

        // Only start
        viewModel.startPoint = start
        #expect(!viewModel.canCreateTrip)
        #expect(!viewModel.isRouteComplete)

        // Only destination
        viewModel.startPoint = nil
        viewModel.destinations = [dest]
        #expect(!viewModel.canCreateTrip)
        #expect(!viewModel.isRouteComplete)

        // Both
        viewModel.startPoint = start
        #expect(viewModel.isRouteComplete)
        #expect(viewModel.canCreateTrip)
    }

    @Test func CanCreateTripIsFalseWhileLoadingRouteOrCreatingTrip() {
        let viewModel = MapViewModel()
        let start = RoutePoint(
            name: "Start",
            subtitle: "Sub",
            coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        )
        let dest = RoutePoint(
            name: "Dest",
            subtitle: "Sub",
            coordinate: CLLocationCoordinate2D(latitude: -6.3, longitude: 106.9)
        )
        viewModel.startPoint = start
        viewModel.destinations = [dest]
        #expect(viewModel.canCreateTrip)

        viewModel.isLoadingRoute = true
        #expect(!viewModel.canCreateTrip)

        viewModel.isLoadingRoute = false
        viewModel.isCreatingTrip = true
        #expect(!viewModel.canCreateTrip)
    }

    @Test func MakeTripPlanBuildsValidPlanWithCheckpoints() {
        let viewModel = MapViewModel()
        let start = RoutePoint(
            name: "Start Point",
            subtitle: "Start Sub",
            coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        )
        let stop1 = RoutePoint(
            name: "Checkpoint 1",
            subtitle: "Stop 1",
            coordinate: CLLocationCoordinate2D(latitude: -6.25, longitude: 106.85)
        )
        let stop2 = RoutePoint(
            name: "Checkpoint 2",
            subtitle: "Stop 2",
            coordinate: CLLocationCoordinate2D(latitude: -6.3, longitude: 106.9)
        )
        let finalDest = RoutePoint(
            name: "Final Destination",
            subtitle: "Dest Sub",
            coordinate: CLLocationCoordinate2D(latitude: -6.35, longitude: 106.95)
        )

        viewModel.startPoint = start
        viewModel.destinations = [stop1, stop2, finalDest]

        let plan = viewModel.MakeTripPlan()
        #expect(plan != nil)
        #expect(plan?.isValid == true)
        #expect(plan?.waypoints.count == 4)
        #expect(plan?.waypoints[0].kind == .start)
        #expect(plan?.waypoints[0].name == "Start Point")
        #expect(plan?.waypoints[1].kind == .checkpoint)
        #expect(plan?.waypoints[1].name == "Checkpoint 1")
        #expect(plan?.waypoints[2].kind == .checkpoint)
        #expect(plan?.waypoints[2].name == "Checkpoint 2")
        #expect(plan?.waypoints[3].kind == .destination)
        #expect(plan?.waypoints[3].name == "Final Destination")
    }

    @Test func MakeTripPlanReturnsNilWhenIncomplete() {
        let viewModel = MapViewModel()
        #expect(viewModel.MakeTripPlan() == nil)

        viewModel.startPoint = RoutePoint(
            name: "Start",
            subtitle: "Sub",
            coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        )
        #expect(viewModel.MakeTripPlan() == nil)
    }

    @Test func CreateTripFailsWhenRouteIncomplete() async {
        let viewModel = MapViewModel()
        #expect(viewModel.startPoint == nil)

        let session = await viewModel.CreateTrip()
        #expect(session == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.isNavigatingToTripRoom)
    }

    @Test func CreateTripSavesTripToServiceAndStorageAndNavigates() async {
        let storage = FakeActiveTripStorage()
        let service = InMemoryTripService()
        let viewModel = MapViewModel(tripService: service, activeTripStorage: storage)

        viewModel.startPoint = RoutePoint(
            name: "Universitas Ciputra",
            subtitle: "Start",
            coordinate: CLLocationCoordinate2D(latitude: -7.28, longitude: 112.63)
        )
        viewModel.destinations = [
            RoutePoint(
                name: "Pakuwon Mall",
                subtitle: "Destination",
                coordinate: CLLocationCoordinate2D(latitude: -7.29, longitude: 112.67)
            )
        ]

        let session = await viewModel.CreateTrip()

        #expect(session != nil)
        #expect(session?.state.trip.roomCode.count == 6)
        #expect(session?.state.trip.status == .lobby)
        #expect(session?.state.trip.leaderParticipantID == session?.myParticipantID)
        #expect(viewModel.createdTripSession == session)
        #expect(viewModel.isNavigatingToTripRoom)
        #expect(viewModel.errorMessage == nil)

        // Storage verification (US-03)
        let loaded = storage.LoadActiveTrip()
        #expect(loaded != nil)
        #expect(loaded?.tripID == session?.state.trip.id)
        #expect(loaded?.isLeader == true)
        #expect(loaded?.startName == "Universitas Ciputra")
        #expect(loaded?.destinationName == "Pakuwon Mall")
    }

    @Test func CreateTripSetsErrorMessageWhenServiceFails() async {
        let storage = FakeActiveTripStorage()
        let service = InMemoryTripService()
        service.simulatedFailure = .noNetwork
        let viewModel = MapViewModel(tripService: service, activeTripStorage: storage)

        viewModel.startPoint = RoutePoint(
            name: "Start",
            subtitle: "Sub",
            coordinate: CLLocationCoordinate2D(latitude: -7.28, longitude: 112.63)
        )
        viewModel.destinations = [
            RoutePoint(
                name: "Dest",
                subtitle: "Sub",
                coordinate: CLLocationCoordinate2D(latitude: -7.29, longitude: 112.67)
            )
        ]

        let session = await viewModel.CreateTrip()

        #expect(session == nil)
        #expect(viewModel.createdTripSession == nil)
        #expect(!viewModel.isNavigatingToTripRoom)
        #expect(viewModel.errorMessage != nil)
        #expect(storage.LoadActiveTrip() == nil)
    }
}
