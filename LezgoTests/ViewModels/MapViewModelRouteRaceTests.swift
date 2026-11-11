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
