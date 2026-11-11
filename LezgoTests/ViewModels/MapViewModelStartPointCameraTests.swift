//
//  MapViewModelStartPointCameraTests.swift
//  LezgoTests
//

import CoreLocation
import MapKit
import SwiftUI
import Testing
@testable import Lezgo

/// The map shows the new start point whenever it changes, with no route to move it there. A far start point is
/// reached in steps (zoom out, cross, zoom in as the tiles load), so the map is never seen empty.
@MainActor
struct MapViewModelStartPointCameraTests {
    private let surabaya = CLLocationCoordinate2D(latitude: -7.2575, longitude: 112.7521)
    private let monas = RoutePoint(
        name: "Monas",
        subtitle: "Jakarta",
        coordinate: CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272)
    )
    /// About 1.6 km from `surabaya`.
    private let tunjungan = RoutePoint(
        name: "Tunjungan Plaza",
        subtitle: "Surabaya",
        coordinate: CLLocationCoordinate2D(latitude: -7.2612, longitude: 112.7378)
    )
    private let wide = 1.0
    private let closeUp = 0.05

    private func MakeViewModel(preloader: MockTilePreloader = MockTilePreloader()) -> MapViewModel {
        let viewModel = MapViewModel(tilePreloader: preloader)
        viewModel.zoomOutTime = .milliseconds(1)
        viewModel.crossingTime = .milliseconds(1)
        viewModel.zoomInTime = .milliseconds(1)
        return viewModel
    }

    /// A view model whose start point is the leader's position in Surabaya.
    private func MakeViewModelStartingInSurabaya(preloader: MockTilePreloader = MockTilePreloader()) -> MapViewModel {
        let viewModel = MakeViewModel(preloader: preloader)
        viewModel.startPoint = RoutePoint(name: "Current Location", subtitle: "GPS Location", coordinate: surabaya)
        return viewModel
    }

    private func Pick(_ place: RoutePoint, in viewModel: MapViewModel) {
        viewModel.activeSelectionSheet = .start
        viewModel.ApplySearchResult(place)
    }

    @Test func ReturningToCurrentLocationMovesTheMapThere() async {
        let viewModel = MakeViewModel()
        viewModel.locationService.userLocation = surabaya
        viewModel.activeSelectionSheet = .start
        viewModel.selectCurrentLocationAsStart()
        await viewModel.startMoveTask?.value

        let center = viewModel.cameraPosition.region?.center
        #expect(center?.latitude == surabaya.latitude)
        #expect(center?.longitude == surabaya.longitude)
    }

    @Test func PickingAStartPointWithNoPreviousOneMovesTheMapThere() async {
        let viewModel = MakeViewModel()
        Pick(tunjungan, in: viewModel)
        await viewModel.startMoveTask?.value

        let center = viewModel.cameraPosition.region?.center
        #expect(center?.latitude == tunjungan.coordinate.latitude)
        #expect(center?.longitude == tunjungan.coordinate.longitude)
    }

    @Test func ANearStartPointIsReachedInOneFlightWithoutLoadingAhead() {
        let preloader = MockTilePreloader()
        let viewModel = MakeViewModelStartingInSurabaya(preloader: preloader)
        Pick(tunjungan, in: viewModel)

        let region = viewModel.cameraPosition.region
        #expect(region?.center.latitude == tunjungan.coordinate.latitude)
        #expect((region?.span.latitudeDelta ?? 1) < closeUp)
        #expect(preloader.requestedAreas.isEmpty)
        #expect(viewModel.startMoveTask == nil)
    }

    @Test func AFarStartPointFirstZoomsOutOverTheOldOne() async {
        let viewModel = MakeViewModelStartingInSurabaya(preloader: MockTilePreloader(isReady: false))
        Pick(monas, in: viewModel)

        while viewModel.cameraPosition.region == nil { await Task.yield() }
        let region = viewModel.cameraPosition.region
        #expect(region?.center.latitude == surabaya.latitude)
        #expect((region?.span.latitudeDelta ?? 0) > wide)
        viewModel.startMoveTask?.cancel()
    }

    @Test func TheCameraCrossesTheDistanceZoomedOutAndWaitsThereForTheTiles() async {
        let viewModel = MakeViewModelStartingInSurabaya(preloader: MockTilePreloader(isReady: false))
        Pick(monas, in: viewModel)

        while viewModel.cameraPosition.region?.center.latitude != monas.coordinate.latitude { await Task.yield() }
        for _ in 0..<50 { await Task.yield() }
        #expect((viewModel.cameraPosition.region?.span.latitudeDelta ?? 0) > wide)
        viewModel.startMoveTask?.cancel()
    }

    @Test func TheCameraZoomsInOnceTheTilesAreLoaded() async {
        let preloader = MockTilePreloader(isReady: false)
        let viewModel = MakeViewModelStartingInSurabaya(preloader: preloader)
        Pick(monas, in: viewModel)

        while viewModel.cameraPosition.region?.center.latitude != monas.coordinate.latitude { await Task.yield() }
        preloader.isReady = true
        await viewModel.startMoveTask?.value

        let region = viewModel.cameraPosition.region
        #expect(region?.center.latitude == monas.coordinate.latitude)
        #expect((region?.span.latitudeDelta ?? 1) < closeUp)
    }

    @Test func SlowTilesDoNotKeepTheCameraFromArriving() async {
        let viewModel = MakeViewModelStartingInSurabaya(preloader: MockTilePreloader(isReady: false))
        viewModel.tileWaitLimit = .milliseconds(1)
        Pick(monas, in: viewModel)
        await viewModel.startMoveTask?.value

        let region = viewModel.cameraPosition.region
        #expect(region?.center.latitude == monas.coordinate.latitude)
        #expect((region?.span.latitudeDelta ?? 1) < closeUp)
    }

    @Test func EveryZoomLevelIsLoadedAroundTheNewStartPoint() async {
        let preloader = MockTilePreloader()
        let viewModel = MakeViewModelStartingInSurabaya(preloader: preloader)
        Pick(monas, in: viewModel)
        await viewModel.startMoveTask?.value

        let distance = MapViewModel.Distance(from: surabaya, to: monas.coordinate)
        let overview = MapViewModel.OverviewArea(forDistance: distance)
        let zoomInAreas = MapViewModel.ZoomInAreas(from: overview)
        #expect(Set(preloader.requestedAreas) == Set([overview] + zoomInAreas))
        let aroundNewStart = zip(preloader.requestedAreas, preloader.requestedCoordinates)
            .filter { zoomInAreas.contains($0.0) }
        #expect(aroundNewStart.count == zoomInAreas.count)
        #expect(aroundNewStart.allSatisfy { $0.1.latitude == monas.coordinate.latitude })
    }

    @Test func TheOverviewIsWiderTheFurtherTheStartPointIs() {
        let neighbourhood = MapViewModel.OverviewArea(forDistance: 6_000)
        let city = MapViewModel.OverviewArea(forDistance: 70_000)
        let country = MapViewModel.OverviewArea(forDistance: 667_000)
        let abroad = MapViewModel.OverviewArea(forDistance: 5_800_000)

        #expect(neighbourhood < city)
        #expect(city < country)
        #expect(country < abroad)
    }

    @Test func TheOverviewFitsBothPlacesWithRoomAround() {
        let distance = 667_000.0
        #expect(MapViewModel.OverviewArea(forDistance: distance) > distance)
    }

    @Test func TheOverviewStaysBetweenANeighbourhoodAndMostOfTheWorld() {
        let limits = MapViewModel.overviewLimits
        #expect(MapViewModel.OverviewArea(forDistance: 100) == limits.lowerBound)
        #expect(MapViewModel.OverviewArea(forDistance: 40_000_000) == limits.upperBound)
    }

    @Test func ShortMovesZoomInInOneOrTwoStepsAndLongOnesInMore() {
        let short = MapViewModel.ZoomInAreas(from: MapViewModel.OverviewArea(forDistance: 6_000))
        let long = MapViewModel.ZoomInAreas(from: MapViewModel.OverviewArea(forDistance: 5_800_000))

        #expect(short.count <= 2)
        #expect(long.count > short.count)
        #expect(long.count <= MapViewModel.maximumZoomInSteps)
    }

    @Test func TheZoomInStepsGetCloserAndEndInTheCloseUp() {
        for distance in [6_000.0, 70_000, 667_000, 5_800_000] {
            let overview = MapViewModel.OverviewArea(forDistance: distance)
            let areas = MapViewModel.ZoomInAreas(from: overview)

            #expect(areas.last == MapViewModel.closeUpArea)
            #expect(areas == areas.sorted(by: >))
            #expect(areas.first ?? 0 < overview)
        }
    }

    @Test func TheCameraStaysWhereItIsUntilTheOverviewTilesAreLoaded() async {
        let preloader = MockTilePreloader()
        preloader.overviewIsReady = false
        let viewModel = MakeViewModelStartingInSurabaya(preloader: preloader)
        Pick(monas, in: viewModel)

        for _ in 0..<50 { await Task.yield() }
        #expect(viewModel.cameraPosition.region == nil)

        preloader.overviewIsReady = true
        await viewModel.startMoveTask?.value
        #expect(viewModel.cameraPosition.region?.center.latitude == monas.coordinate.latitude)
    }

    @Test func ANewMoveReplacesTheOneStillRunning() async {
        let preloader = MockTilePreloader(isReady: false)
        let viewModel = MakeViewModelStartingInSurabaya(preloader: preloader)
        Pick(monas, in: viewModel)
        let first = viewModel.startMoveTask

        preloader.isReady = true
        viewModel.locationService.userLocation = surabaya
        viewModel.activeSelectionSheet = .start
        viewModel.selectCurrentLocationAsStart()
        await viewModel.startMoveTask?.value

        #expect(first?.isCancelled == true)
        #expect(viewModel.cameraPosition.region?.center.latitude != monas.coordinate.latitude)
    }
}
