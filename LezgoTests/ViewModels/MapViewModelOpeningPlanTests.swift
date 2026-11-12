//
//  MapViewModelOpeningPlanTests.swift
//  LezgoTests
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

/// Edit Route and New Destination open the planner with a route already in it, so only a different route counts as a
/// change worth asking about when going back.
@MainActor
struct MapViewModelOpeningPlanTests {
    private func Waypoints(_ names: [String]) -> [PlannedWaypoint] {
        names.enumerated().map { index, name in
            PlannedWaypoint(
                kind: index == 0 ? .start : .checkpoint,
                name: name,
                coordinate: Coordinate(latitude: -7.0 - Double(index), longitude: 112)
            )
        }
    }

    private func Stop(_ name: String) -> RoutePoint {
        RoutePoint(name: name, subtitle: "", coordinate: CLLocationCoordinate2D(latitude: -7.3, longitude: 112))
    }

    @Test func PlannerOpenedOnATripRouteHasNoChangesUntilTheRouteDiffers() {
        let viewModel = MapViewModel(startingWaypoints: Waypoints(["Start", "UNEJ", "ITS"]))
        #expect(!viewModel.hasPlanChanges)

        viewModel.destinations.swapAt(0, 1)
        #expect(viewModel.hasPlanChanges)

        viewModel.destinations.swapAt(0, 1)
        #expect(!viewModel.hasPlanChanges)

        viewModel.destinations.removeLast()
        #expect(viewModel.hasPlanChanges)
    }

    @Test func PlannerOpenedOnATripRouteSeesAnAddedStop() {
        let viewModel = MapViewModel(startingWaypoints: Waypoints(["Start", "UNEJ"]))

        viewModel.destinations.append(Stop("ITS"))

        #expect(viewModel.hasPlanChanges)
    }

    /// New Destination opens with only the old destination as the start point.
    @Test func PlannerOpenedOnlyOnAStartPointHasNoChangesUntilAStopIsAdded() {
        let viewModel = MapViewModel(startingWaypoints: Waypoints(["Start"]))
        #expect(!viewModel.hasPlanChanges)

        viewModel.destinations.append(Stop("ITS"))
        #expect(viewModel.hasPlanChanges)
    }
}
