//
//  MapViewModelMapPickerTests.swift
//  LezgoTests
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

@MainActor
struct MapViewModelMapPickerTests {
    private let darmo = RoutePoint(
        name: "Darmo",
        subtitle: "Surabaya",
        coordinate: CLLocationCoordinate2D(latitude: -7.2900, longitude: 112.7340)
    )
    private let tunjungan = RoutePoint(
        name: "Tunjungan Plaza",
        subtitle: "Genteng",
        coordinate: CLLocationCoordinate2D(latitude: -7.2620, longitude: 112.7380)
    )

    private func MakeViewModel() -> MapViewModel {
        MapViewModel(
            routingService: MockRouteCalculator(),
            tilePreloader: MockTilePreloader(),
            placeLookupService: MockPlaceLookupService()
        )
    }

    @Test func PickingOnTheMapNeedsAnActiveSelection() {
        let viewModel = MakeViewModel()

        viewModel.StartPickingOnMap()

        #expect(viewModel.mapPicker == nil)
    }

    @Test func ThePickerOpensAtThePointBeingEdited() {
        let viewModel = MakeViewModel()
        viewModel.destinations = [tunjungan]
        viewModel.activeSelectionSheet = .destination(index: 0)

        viewModel.StartPickingOnMap()

        #expect(viewModel.mapPicker?.selection == .destination(index: 0))
        #expect(viewModel.mapPicker?.center.latitude == tunjungan.coordinate.latitude)
    }

    @Test func ThePickerOpensAtTheStartPointForANewStop() {
        let viewModel = MakeViewModel()
        viewModel.startPoint = darmo
        viewModel.activeSelectionSheet = .destination(index: 0)

        viewModel.StartPickingOnMap()

        #expect(viewModel.mapPicker?.center.latitude == darmo.coordinate.latitude)
    }

    @Test func ConfirmingThePickPutsThePlaceInTheRouteAndClosesEverything() async {
        let viewModel = MakeViewModel()
        viewModel.startPoint = darmo
        viewModel.activeSelectionSheet = .destination(index: 0)
        viewModel.StartPickingOnMap()
        viewModel.mapPicker?.CameraMoved(to: Coordinate(latitude: -7.2620, longitude: 112.7380))
        await viewModel.mapPicker?.lookupTask?.value

        viewModel.ConfirmMapPick()

        #expect(viewModel.destinations.count == 1)
        #expect(viewModel.destinations[0].coordinate.latitude == -7.2620)
        #expect(viewModel.mapPicker == nil)
        #expect(viewModel.activeSelectionSheet == nil)
    }

    @Test func ConfirmingForTheStartPointReplacesIt() {
        let viewModel = MakeViewModel()
        viewModel.startPoint = darmo
        viewModel.activeSelectionSheet = .start
        viewModel.StartPickingOnMap()
        viewModel.mapPicker?.CameraMoved(to: Coordinate(latitude: -7.2620, longitude: 112.7380))

        viewModel.ConfirmMapPick()

        #expect(viewModel.startPoint?.coordinate.latitude == -7.2620)
        #expect(viewModel.destinations.isEmpty)
    }

    @Test func ClosingThePickerChangesNothing() {
        let viewModel = MakeViewModel()
        viewModel.startPoint = darmo
        viewModel.destinations = [tunjungan]
        viewModel.activeSelectionSheet = .destination(index: 0)
        viewModel.StartPickingOnMap()
        viewModel.mapPicker?.CameraMoved(to: Coordinate(latitude: -7.0, longitude: 112.0))

        viewModel.CancelMapPick()

        #expect(viewModel.mapPicker == nil)
        #expect(viewModel.activeSelectionSheet == .destination(index: 0))
        #expect(viewModel.destinations == [tunjungan])
        #expect(viewModel.startPoint == darmo)
    }
}
