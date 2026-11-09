//
//  EditRouteViewModelTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 29/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Saving the route the leader changed in Edit Route (`specs/UserStories.md` → US-06, "Route changes").
struct EditRouteViewModelTests {
    private typealias Fixtures = TripMapFixtures

    private static let startingWaypoints = [
        PlannedWaypoint(kind: .start, name: "Current Location", coordinate: Fixtures.startPoint.coordinate),
        PlannedWaypoint(kind: .destination, name: "Pakuwon mall", coordinate: Fixtures.destination.coordinate)
    ]

    /// The destination changed to "Pakuwon city mall".
    private static let changedPlan = TripPlan(
        waypoints: [
            PlannedWaypoint(kind: .start, name: "Current Location", coordinate: Fixtures.startPoint.coordinate),
            PlannedWaypoint(kind: .destination, name: "Pakuwon city mall", coordinate: Fixtures.checkpoint.coordinate)
        ],
        polyline: [Fixtures.startPoint.coordinate, Fixtures.checkpoint.coordinate]
    )

    private func MakeViewModel(service: MockTripService) -> EditRouteViewModel {
        EditRouteViewModel(
            startingWaypoints: Self.startingWaypoints,
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: service
        )
    }

    @Test func SaveSendsTheChangedRouteForEveryone() async {
        let service = MockTripService(states: [])
        let viewModel = MakeViewModel(service: service)

        await viewModel.Save(Self.changedPlan)

        #expect(service.savedRoutes == [Self.changedPlan])
        #expect(viewModel.didSave)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func FailedSaveKeepsTheSheetOpenWithAMessage() async {
        let service = MockTripService(states: [])
        service.nextSaveRouteFailure = .noNetwork
        let viewModel = MakeViewModel(service: service)

        await viewModel.Save(Self.changedPlan)

        #expect(service.savedRoutes.isEmpty)
        #expect(viewModel.didSave == false)
        #expect(viewModel.errorMessage == String(localized: TripServiceError.noNetwork.message))
        #expect(viewModel.isSaving == false)
    }

    @Test func SaveWorksAgainAfterAFailure() async {
        let service = MockTripService(states: [])
        service.nextSaveRouteFailure = .noNetwork
        let viewModel = MakeViewModel(service: service)
        await viewModel.Save(Self.changedPlan)

        await viewModel.Save(Self.changedPlan)

        #expect(service.savedRoutes == [Self.changedPlan])
        #expect(viewModel.didSave)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func RouteWithoutADestinationIsNotSaved() async {
        let service = MockTripService(states: [])
        let viewModel = MakeViewModel(service: service)
        let noDestination = TripPlan(waypoints: [Self.startingWaypoints[0]], polyline: [])

        await viewModel.Save(noDestination)

        #expect(service.savedRoutes.isEmpty)
        #expect(viewModel.didSave == false)
        #expect(viewModel.errorMessage == String(localized: TripServiceError.notAllowed.message))
    }

    @Test func SecondSaveAfterSuccessDoesNothing() async {
        let service = MockTripService(states: [])
        let viewModel = MakeViewModel(service: service)

        await viewModel.Save(Self.changedPlan)
        await viewModel.Save(Self.changedPlan)

        #expect(service.savedRoutes.count == 1)
    }

    @Test func SecondSaveWhileTheFirstIsOnItsWayDoesNothing() async {
        let service = MockTripService(states: [])
        let viewModel = MakeViewModel(service: service)
        service.whileSavingRoute = {
            #expect(viewModel.isSaving)
            await viewModel.Save(Self.changedPlan)
        }

        await viewModel.Save(Self.changedPlan)

        #expect(service.savedRoutes.count == 1)
    }

    @Test func DismissErrorClearsTheMessage() async {
        let service = MockTripService(states: [])
        service.nextSaveRouteFailure = .noNetwork
        let viewModel = MakeViewModel(service: service)
        await viewModel.Save(Self.changedPlan)

        viewModel.DismissError()

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: New Destination

    private func MakeNewDestinationViewModel(service: MockTripService) -> EditRouteViewModel {
        EditRouteViewModel(
            startingWaypoints: [Self.startingWaypoints[0]],
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: service,
            purpose: .newDestination
        )
    }

    @Test func NewDestinationStartsTheNextLegInsteadOfChangingTheRoute() async {
        let service = MockTripService(states: [])
        let viewModel = MakeNewDestinationViewModel(service: service)

        await viewModel.Save(Self.changedPlan)

        #expect(service.newDestinationPlans == [Self.changedPlan])
        #expect(service.savedRoutes.isEmpty)
        #expect(viewModel.didSave)
    }

    @Test func FailedNewDestinationKeepsThePlannerOpenWithAMessage() async {
        let service = MockTripService(states: [])
        service.nextSaveRouteFailure = .noNetwork
        let viewModel = MakeNewDestinationViewModel(service: service)

        await viewModel.Save(Self.changedPlan)

        #expect(service.newDestinationPlans.isEmpty)
        #expect(viewModel.didSave == false)
        #expect(viewModel.errorMessage == String(localized: TripServiceError.noNetwork.message))
    }
}
