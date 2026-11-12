//
//  MapPickerViewModelTests.swift
//  LezgoTests
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

@MainActor
struct MapPickerViewModelTests {
    private let start = Coordinate(latitude: -7.2900, longitude: 112.7340)
    /// About 22 m north of `start`.
    private let nearStart = Coordinate(latitude: -7.2898, longitude: 112.7340)
    /// About 550 m north of `start`.
    private let farFromStart = Coordinate(latitude: -7.2850, longitude: 112.7340)
    private let darmo = PlaceAddress(street: "Jl. Raya Darmo", area: "Surabaya")
    private let tunjungan = NearbyPlace(
        name: "Tunjungan Plaza",
        subtitle: "Jl. Basuki Rahmat",
        coordinate: Coordinate(latitude: -7.2620, longitude: 112.7380)
    )

    private func MakeViewModel(
        selection: ActivePointSelection = .start,
        service: MockPlaceLookupService = MockPlaceLookupService(),
        debounce: Duration = .zero
    ) -> MapPickerViewModel {
        MapPickerViewModel(selection: selection, startingAt: start, lookupService: service, debounce: debounce)
    }

    @Test func StartLooksUpTheAddressAndNearbyPlacesAtTheStartingPoint() async {
        let service = MockPlaceLookupService(nearbyResult: .success([tunjungan]))
        let viewModel = MakeViewModel(service: service)

        viewModel.Start()
        await viewModel.lookupTask?.value

        #expect(viewModel.address == darmo)
        #expect(viewModel.nearbyPlaces == [tunjungan])
        #expect(service.requestedAddresses == [start])
        #expect(!viewModel.isLoadingAddress)
    }

    @Test func TheAddressIsLoadingUntilTheLookupEnds() async {
        let viewModel = MakeViewModel()

        viewModel.CameraMoved(to: farFromStart)
        #expect(viewModel.isLoadingAddress)

        await viewModel.lookupTask?.value
        #expect(!viewModel.isLoadingAddress)
    }

    @Test func MovingTheMapUpdatesTheCenterAndTheAddress() async {
        let service = MockPlaceLookupService(addressResults: [.success(darmo)])
        let viewModel = MakeViewModel(service: service)

        viewModel.CameraMoved(to: farFromStart)
        await viewModel.lookupTask?.value

        #expect(viewModel.center == farFromStart)
        #expect(viewModel.address == darmo)
    }

    /// The card changes height while the address loads, which makes the map settle again on the same point and
    /// report the same center; looking up again would cancel the lookup before it ends, so the address never shows.
    @Test func TheSameCenterReportedAgainIsNotLookedUpAgain() async {
        let service = MockPlaceLookupService()
        let viewModel = MakeViewModel(service: service)
        viewModel.Start()
        await viewModel.lookupTask?.value

        viewModel.CameraMoved(to: start)
        await viewModel.lookupTask?.value

        #expect(service.requestedAddresses == [start])
        #expect(viewModel.address == darmo)
    }

    @Test func OnlyTheLastOfQuickMovesIsLookedUp() async {
        let service = MockPlaceLookupService()
        let viewModel = MakeViewModel(service: service, debounce: .milliseconds(50))

        viewModel.CameraMoved(to: nearStart)
        viewModel.CameraMoved(to: farFromStart)
        await viewModel.lookupTask?.value

        #expect(service.requestedAddresses == [farFromStart])
    }

    @Test func AFailedLookupLeavesNoOldAddress() async {
        let service = MockPlaceLookupService(addressResults: [.success(darmo), .failure(.init())])
        let viewModel = MakeViewModel(service: service)
        viewModel.Start()
        await viewModel.lookupTask?.value

        viewModel.CameraMoved(to: farFromStart)
        await viewModel.lookupTask?.value

        #expect(viewModel.address == nil)
        #expect(viewModel.addressNotFound)
        #expect(!viewModel.isLoadingAddress)
    }

    @Test func NearbyPlacesAreNotAskedAgainForASmallMove() async {
        let service = MockPlaceLookupService()
        let viewModel = MakeViewModel(service: service)
        viewModel.Start()
        await viewModel.lookupTask?.value

        viewModel.CameraMoved(to: nearStart)
        await viewModel.lookupTask?.value

        #expect(service.requestedAddresses.count == 2)
        #expect(service.requestedNearby.count == 1)
    }

    @Test func NearbyPlacesAreAskedAgainForABigMove() async {
        let service = MockPlaceLookupService()
        let viewModel = MakeViewModel(service: service)
        viewModel.Start()
        await viewModel.lookupTask?.value

        viewModel.CameraMoved(to: farFromStart)
        await viewModel.lookupTask?.value

        #expect(service.requestedNearby.count == 2)
    }

    @Test func ChoosingANearbyPlaceMovesThePinToItAndKeepsItsName() {
        let viewModel = MakeViewModel()

        viewModel.Snap(to: tunjungan)

        #expect(viewModel.center == tunjungan.coordinate)
        #expect(viewModel.address == PlaceAddress(street: "Tunjungan Plaza", area: "Jl. Basuki Rahmat"))
    }

    /// The camera move that follows a snap ends a few metres from the place; it must not rename the place.
    @Test func TheMapSettlingOnASnappedPlaceDoesNotLookItUpAgain() async {
        let service = MockPlaceLookupService()
        let viewModel = MakeViewModel(service: service)
        viewModel.Snap(to: tunjungan)

        viewModel.CameraMoved(to: Coordinate(latitude: -7.26201, longitude: 112.73801))
        await viewModel.lookupTask?.value

        #expect(service.requestedAddresses.isEmpty)
        #expect(viewModel.address?.street == "Tunjungan Plaza")
    }

    @Test func MovingAwayFromASnappedPlaceLooksUpTheNewAddress() async {
        let service = MockPlaceLookupService()
        let viewModel = MakeViewModel(service: service)
        viewModel.Snap(to: tunjungan)

        viewModel.CameraMoved(to: farFromStart)
        await viewModel.lookupTask?.value

        #expect(service.requestedAddresses == [farFromStart])
        #expect(viewModel.address == darmo)
    }

    @Test func ThePinLiftsWhileTheMapMovesAndDropsWhenItStops() {
        let viewModel = MakeViewModel()

        viewModel.CameraIsMoving()
        #expect(viewModel.isMoving)

        viewModel.CameraMoved(to: farFromStart)
        #expect(!viewModel.isMoving)
    }

    @Test func TheConfirmedPointCarriesTheAddressAndTheCenter() async {
        let viewModel = MakeViewModel()
        viewModel.CameraMoved(to: farFromStart)
        await viewModel.lookupTask?.value

        let point = viewModel.MakePoint()

        #expect(point.name == "Jl. Raya Darmo")
        #expect(point.subtitle == "Surabaya")
        #expect(point.coordinate.latitude == farFromStart.latitude)
        #expect(point.coordinate.longitude == farFromStart.longitude)
    }

    @Test func TheConfirmedPointHasAFallbackNameWithoutAnAddress() {
        let viewModel = MakeViewModel()

        let point = viewModel.MakePoint()

        #expect(point.name == String(localized: "Pinned location"))
    }

    @Test func TheTitleFollowsTheSelection() {
        #expect(MakeViewModel(selection: .start).title == "Starting Point")
        #expect(MakeViewModel(selection: .destination(index: 0)).title == "Destination")
        #expect(MakeViewModel(selection: .destination(index: 1)).title == "Stop 2")
    }
}
