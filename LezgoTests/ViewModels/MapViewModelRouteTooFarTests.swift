//
//  MapViewModelRouteTooFarTests.swift
//  LezgoTests
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

/// When no route exists between the stops, the planner says they are too far apart and offers to edit the point that
/// was changed last (`specs/UserStories.md` → US-01).
@MainActor
struct MapViewModelRouteTooFarTests {
    private func Point(_ name: String, _ latitude: Double) -> RoutePoint {
        RoutePoint(name: name, subtitle: "", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 113))
    }

    private func Wait(until condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
    }

    private func PlanWithAFailingRoute(_ failure: any Error) async -> MapViewModel {
        let calculator = MockRouteCalculator()
        let viewModel = MapViewModel(routingService: calculator)
        viewModel.startPoint = Point("Surabaya", -7)
        viewModel.destinations = [Point("Tokyo", 35)]

        viewModel.findRoute()
        await Wait { calculator.pendingCount == 1 }
        calculator.Finish(call: 0, with: .failure(failure))
        await Wait { !viewModel.isLoadingRoute }
        return viewModel
    }

    @Test func NoRouteShowsTheTooFarDialogNotAnErrorMessage() async {
        let viewModel = await PlanWithAFailingRoute(RoutingError.noRoute)

        #expect(viewModel.isRouteTooFar)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.routeLegs.isEmpty)
    }

    @Test func OtherFailuresKeepTheirOwnMessage() async {
        let viewModel = await PlanWithAFailingRoute(URLError(.notConnectedToInternet))

        #expect(viewModel.isRouteTooFar == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test(arguments: [ActivePointSelection.start, .destination(index: 0)])
    func EditingOffersTheSearchOfThePointChangedLast(point: ActivePointSelection) async {
        let viewModel = await PlanWithAFailingRoute(RoutingError.noRoute)
        viewModel.activeSelectionSheet = point
        viewModel.ApplySearchResult(Point("Picked", 35))
        #expect(viewModel.lastEditedPoint == point)

        viewModel.isRouteTooFar = true
        viewModel.EditTooFarPoint()

        #expect(viewModel.activeSelectionSheet == point)
        #expect(viewModel.isRouteTooFar == false)
    }

    @Test func WithoutAnEditTheLastDestinationIsOffered() async {
        let viewModel = await PlanWithAFailingRoute(RoutingError.noRoute)

        viewModel.EditTooFarPoint()

        #expect(viewModel.activeSelectionSheet == .destination(index: 0))
    }

    @Test func FindingARouteAgainClosesTheTooFarDialog() async {
        let calculator = MockRouteCalculator()
        let viewModel = MapViewModel(routingService: calculator)
        viewModel.startPoint = Point("A", -7)
        viewModel.destinations = [Point("B", -8)]
        viewModel.isRouteTooFar = true

        viewModel.findRoute()

        #expect(viewModel.isRouteTooFar == false)
    }
}
