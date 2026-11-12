//
//  MapPickerViewModel.swift
//  Lezgo
//

import MapKit
import SwiftUI

/// The state of the "Choose on Map" screen: where the pin is, what is there, and what is around it.
///
/// The pin stays at the center of the screen and the map moves under it, so the pin's place is the center of the
/// map's camera. The address is looked up only after the map stops, because Apple limits how many requests an app
/// sends.
@Observable
final class MapPickerViewModel {
    /// A move shorter than this keeps the nearby places; the chips would be nearly the same.
    static let nearbyRefreshDistance: CLLocationDistance = 100
    /// A map that settles this close to a snapped place is still on that place.
    static let snapTolerance: CLLocationDistance = 30

    let selection: ActivePointSelection
    var cameraPosition: MapCameraPosition
    private(set) var center: Coordinate
    private(set) var address: PlaceAddress?
    private(set) var isLoadingAddress = false
    /// `true` when the last lookup found nothing or failed, so the card says so instead of showing an old address.
    private(set) var addressNotFound = false
    private(set) var nearbyPlaces: [NearbyPlace] = []
    /// `true` while the map moves, so the pin lifts.
    private(set) var isMoving = false
    /// The latest lookup; an older one is cancelled so it cannot answer for a place the pin has left.
    private(set) var lookupTask: Task<Void, Never>?

    private let lookupService: any PlaceLookupService
    private let debounce: Duration
    private var nearbyCenter: Coordinate?
    private var snappedPlace: NearbyPlace?

    var title: String { selection.title }

    init(
        selection: ActivePointSelection,
        startingAt start: Coordinate,
        lookupService: any PlaceLookupService,
        debounce: Duration = .milliseconds(300)
    ) {
        self.selection = selection
        self.center = start
        self.lookupService = lookupService
        self.debounce = debounce
        self.cameraPosition = MapViewModel.CloseUp(of: start.locationCoordinate)
    }

    /// Looks up the place the screen opened on.
    func Start() {
        Lookup(at: center, after: .zero)
    }

    func CameraIsMoving() {
        isMoving = true
    }

    /// The map stopped at `coordinate`.
    func CameraMoved(to coordinate: Coordinate) {
        isMoving = false
        center = coordinate
        if let snappedPlace, snappedPlace.coordinate.Distance(to: coordinate) <= Self.snapTolerance { return }
        snappedPlace = nil
        Lookup(at: coordinate, after: debounce)
    }

    /// Moves the pin onto a nearby place and shows that place's own name.
    func Snap(to place: NearbyPlace) {
        lookupTask?.cancel()
        snappedPlace = place
        center = place.coordinate
        address = PlaceAddress(street: place.name, area: place.subtitle)
        isLoadingAddress = false
        addressNotFound = false
        cameraPosition = MapViewModel.CloseUp(of: place.coordinate.locationCoordinate)
    }

    /// The point to put in the route: the address when there is one, a plain name when there is not.
    func MakePoint() -> RoutePoint {
        RoutePoint(
            name: address?.street ?? String(localized: "Pinned location"),
            subtitle: address?.area ?? "",
            coordinate: center.locationCoordinate
        )
    }

    private func Lookup(at coordinate: Coordinate, after delay: Duration) {
        lookupTask?.cancel()
        isLoadingAddress = true
        addressNotFound = false
        let wantsNearby = nearbyCenter.map { $0.Distance(to: coordinate) >= Self.nearbyRefreshDistance } ?? true
        lookupTask = Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard Task.isCancelled == false else { return }
            await FindAddress(at: coordinate)
            if wantsNearby, Task.isCancelled == false { await FindNearbyPlaces(around: coordinate) }
        }
    }

    private func FindAddress(at coordinate: Coordinate) async {
        let found: PlaceAddress?
        do {
            found = try await lookupService.Address(at: coordinate)
        } catch {
            found = nil
        }
        guard Task.isCancelled == false else { return }
        address = found
        addressNotFound = found == nil
        isLoadingAddress = false
    }

    private func FindNearbyPlaces(around coordinate: Coordinate) async {
        guard let places = try? await lookupService.NearbyPlaces(around: coordinate) else { return }
        guard Task.isCancelled == false else { return }
        nearbyPlaces = places
        nearbyCenter = coordinate
    }
}
