//
//  MapViewModelRouteRaceTests.swift
//  LezgoTests
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

@MainActor
struct MapViewModelRouteRaceTests {
    private func Point(_ name: String, _ latitude: Double) -> RoutePoint {
        RoutePoint(name: name, subtitle: "", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 113))
    }

    private func Wait(until condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
    }

    /// Waits for something that happens after a real delay, which yielding alone does not wait for.
    private func WaitForDelay(until condition: () -> Bool) async {
        for _ in 0..<300 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Reordering stops again before the first calculation ends must not show the error of the old calculation.
    @Test func OldCalculationThatFailsAfterAReorderShowsNoNotice() async {
        let calculator = MockRouteCalculator()
        let viewModel = MapViewModel(routingService: calculator)
        let start = Point("Start", -7.0)
        viewModel.startPoint = start
        viewModel.destinations = [Point("UNEJ", -8.1), Point("ITS", -7.3)]

        viewModel.findRoute()
        await Wait { calculator.pendingCount == 1 }
        viewModel.moveDestination(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        await Wait { calculator.pendingCount == 2 }

        calculator.Finish(call: 1, with: .success([]))
        await Wait { !viewModel.isLoadingRoute }
        calculator.Finish(call: 0, with: .failure(URLError(.cannotConnectToHost)))
        for _ in 0..<20 { await Task.yield() }

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.routedPoints == [start] + viewModel.destinations)
    }

    /// MapKit refusing for a minute is told to the user, and the route is asked for again once it answers.
    @Test func ThrottledRouteTellsTheUserAndTriesAgainAfterTheWait() async {
        let calculator = MockRouteCalculator()
        let viewModel = MapViewModel(routingService: calculator)
        viewModel.startPoint = Point("Start", -7.0)
        viewModel.destinations = [Point("UNEJ", -8.1), Point("ITS", -7.3)]

        viewModel.findRoute()
        await Wait { calculator.pendingCount == 1 }
        calculator.Finish(call: 0, with: .failure(RoutingError.throttled(retryAfter: 0.5)))
        await Wait { viewModel.errorMessage != nil }

        #expect(viewModel.errorMessage == "Too many route requests. Trying again in a moment.")
        #expect(viewModel.isLoadingRoute == false)

        await WaitForDelay { calculator.pendingCount == 2 }
        #expect(calculator.pendingCount == 2)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoadingRoute)
    }

    /// Stops changed during the wait are asked for once, not once for the wait and once for the change.
    @Test func ThrottledRouteDoesNotTryAgainAfterTheStopsChanged() async {
        let calculator = MockRouteCalculator()
        let viewModel = MapViewModel(routingService: calculator)
        viewModel.startPoint = Point("Start", -7.0)
        viewModel.destinations = [Point("UNEJ", -8.1), Point("ITS", -7.3)]

        viewModel.findRoute()
        await Wait { calculator.pendingCount == 1 }
        calculator.Finish(call: 0, with: .failure(RoutingError.throttled(retryAfter: 0.2)))
        await Wait { viewModel.errorMessage != nil }
        viewModel.moveDestination(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        await Wait { calculator.pendingCount == 2 }
        try? await Task.sleep(for: .milliseconds(400))

        #expect(calculator.pendingCount == 2)
    }

    /// An old calculation that ends last must not replace the route of the newest order.
    @Test func OldCalculationThatEndsLastDoesNotReplaceTheNewRoute() async {
        let calculator = MockRouteCalculator()
        let viewModel = MapViewModel(routingService: calculator)
        let start = Point("Start", -7.0)
        viewModel.startPoint = start
        viewModel.destinations = [Point("UNEJ", -8.1), Point("ITS", -7.3)]
        let oldOrder = [start] + viewModel.destinations

        viewModel.findRoute()
        await Wait { calculator.pendingCount == 1 }
        viewModel.moveDestination(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        await Wait { calculator.pendingCount == 2 }

        calculator.Finish(call: 1, with: .success([]))
        await Wait { !viewModel.isLoadingRoute }
        calculator.Finish(call: 0, with: .success([]))
        for _ in 0..<20 { await Task.yield() }

        #expect(viewModel.routedPoints == [start] + viewModel.destinations)
        #expect(viewModel.routedPoints != oldOrder)
    }
}
