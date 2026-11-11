//
//  MapViewModel.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//

import SwiftUI
import MapKit
import CoreLocation

@Observable
final class MapViewModel {
    // MARK: - Dependencies & Services
    let routingService: any RouteCalculating
    /// The calculation for the latest order of the stops; an older one is cancelled so it cannot answer late.
    var routeTask: Task<Void, Never>?
    let tilePreloader: any TilePreloading
    /// The latest move to a new start point; an older one is cancelled so it cannot move the camera after a newer one.
    var startMoveTask: Task<Void, Never>?
    /// How long each step of a move to a far start point lasts. They match the animations of the steps.
    var zoomOutTime: Duration = .milliseconds(800)
    var crossingTime: Duration = .milliseconds(1_000)
    var zoomInTime: Duration = .milliseconds(800)
    /// The longest the camera waits for the tiles of one zoom level.
    var tileWaitLimit: Duration = .seconds(4)
    let searchService = LocationFindService()
    let locationService = LocationService()
    var tripService: any TripService
    var activeTripStorage: any ActiveTripStorage
    /// Names the place where the trip starts when the start point is the leader's position.
    let streetNameService: any StreetNameService
    /// My name and car, shown to the group as the leader.
    let profileStorage: any ProfileStorage

    // MARK: - Route Planning State
    var startPoint: RoutePoint?
    var destinations: [RoutePoint] = []

    // MARK: - Trip Creation State
    var isCreatingTrip: Bool = false
    var createdSession: TripSession?

    // MARK: - Computed Trip & Map State
    var routeLegs: [RouteLeg] = []
    /// The start point and stops `routeLegs` were found for. After a failed or out-of-order calculation they differ
    /// from the current stops, and the route on the map must not be saved for them.
    var routedPoints: [RoutePoint] = []

    var totalDistance: CLLocationDistance {
        routeLegs.reduce(0) { $0 + $1.selectedRoute.distance }
    }

    var totalDuration: TimeInterval {
        routeLegs.reduce(0) { $0 + $1.selectedRoute.expectedTravelTime }
    }

    var combinedPolyline: MKPolyline? {
        var allCoordinates: [CLLocationCoordinate2D] = []
        for leg in routeLegs {
            let poly = leg.selectedRoute.polyline
            var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: poly.pointCount)
            poly.getCoordinates(&coords, range: NSRange(location: 0, length: poly.pointCount))
            allCoordinates.append(contentsOf: coords)
        }
        guard !allCoordinates.isEmpty else { return nil }
        return MKPolyline(coordinates: allCoordinates, count: allCoordinates.count)
    }

    var hasRoute: Bool {
        !routeLegs.isEmpty
    }

    var hasPlanChanges: Bool {
        !destinations.isEmpty || (startPoint != nil && startPoint?.name != "Current Location")
    }

    var cameraPosition: MapCameraPosition = .automatic
    var isLocationAuthorized: Bool {
        locationService.isAuthorized
    }
    var isLoadingRoute: Bool = false
    var errorMessage: String?

    var canCreateTrip: Bool {
        !isLoadingRoute && !isCreatingTrip && MakeTripPlan() != nil
    }

    // MARK: - Modal Search Presentation State
    var activeSelectionSheet: ActivePointSelection?
    var searchQuery: String = ""

    var isSearching: Bool {
        activeSelectionSheet != nil
    }

    init(
        routingService: (any RouteCalculating)? = nil,
        tilePreloader: (any TilePreloading)? = nil,
        tripService: (any TripService)? = nil,
        activeTripStorage: (any ActiveTripStorage)? = nil,
        profileStorage: (any ProfileStorage)? = nil,
        streetNameService: (any StreetNameService)? = nil
    ) {
        self.routingService = routingService ?? RoutingService()
        self.tilePreloader = tilePreloader ?? LiveTilePreloader()
        self.tripService = tripService ?? InMemoryTripService()
        self.activeTripStorage = activeTripStorage ?? UserDefaultsActiveTripStorage()
        self.profileStorage = profileStorage ?? UserDefaultsProfileStorage()
        self.streetNameService = streetNameService ?? LiveStreetNameService()

        // Automatically default the start point to the first GPS fix
        locationService.onFirstLocationFound = { [weak self] coord in
            guard let self = self else { return }
            if self.startPoint == nil {
                self.startPoint = RoutePoint(
                    name: String(localized: .waypointCurrentLocation),
                    subtitle: "GPS Location",
                    coordinate: coord
                )
                // If the user already picked a destination, trigger route calculation immediately
                if !self.destinations.isEmpty {
                    self.findRoute()
                }
            }
            if self.routeLegs.isEmpty {
                self.FlyCamera(to: .userLocation(fallback: .automatic))
            }
        }
    }

    // MARK: - Lifecycle
    func onAppear() {
        locationService.requestPermission()
        // Prompt the user for destination first if not set
        if destinations.isEmpty {
            activeSelectionSheet = .destination(index: 0)
        }
    }

    // MARK: - Reset / Clear
    func clearDestinationSearch() {
        destinations.removeAll()
        routeLegs.removeAll()
        activeSelectionSheet = nil
        searchQuery = ""
        searchService.updateQueryFragment("")
        errorMessage = nil
        createdSession = nil
        isCreatingTrip = false
        if let currentCoord = locationService.userLocation {
            startPoint = RoutePoint(
                name: "Current Location",
                subtitle: "GPS Location",
                coordinate: currentCoord
            )
        }
        cameraPosition = .userLocation(fallback: .automatic)
    }

    // MARK: - Destinations Management
    func addDestination() {
        let newIndex = destinations.count
        activeSelectionSheet = .destination(index: newIndex)
    }

    func removeDestination(at index: Int) {
        guard destinations.indices.contains(index) else { return }
        destinations.remove(at: index)
        findRoute()
    }

    func moveDestination(fromOffsets: IndexSet, toOffset: Int) {
        destinations.move(fromOffsets: fromOffsets, toOffset: toOffset)
        findRoute()
    }

    // MARK: - Search Handling
    func onSearchQueryChanged(_ newQuery: String) {
        let reference = locationService.userLocation ?? startPoint?.coordinate
        searchService.updateQueryFragment(newQuery, referenceLocation: reference)
    }

    func selectCurrentLocationAsStart() {
        guard let current = locationService.userLocation else { return }
        let previous = startPoint?.coordinate
        startPoint = RoutePoint(
            name: String(localized: .waypointCurrentLocation),
            subtitle: "GPS Location",
            coordinate: current
        )
        closeSearch()
        findRoute()
        // A route moves the map to fit it once found; without a destination there is none, so show the start.
        if destinations.isEmpty {
            ShowStart(from: previous, to: current)
        }
    }

    func selectSearchResult(_ item: SearchResultItem) {
        Task {
            do {
                let resolved = try await searchService.resolveLocation(from: item)
                await MainActor.run { self.ApplySearchResult(resolved) }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not resolve coordinates for this location."
                }
            }
        }
    }

    /// Puts the picked place where the search was for, then finds the route through the stops.
    func ApplySearchResult(_ resolved: RoutePoint) {
        guard let active = activeSelectionSheet else { return }
        let previous = startPoint?.coordinate
        switch active {
        case .start:
            startPoint = resolved
        case .destination(let index):
            if index < destinations.count {
                destinations[index] = resolved
            } else {
                destinations.append(resolved)
            }
        }

        closeSearch()
        findRoute()
        // A route moves the map to fit it once found; without a destination there is none, so show the start.
        if active == .start, destinations.isEmpty {
            ShowStart(from: previous, to: resolved.coordinate)
        }
    }

    func closeSearch() {
        activeSelectionSheet = nil
        searchQuery = ""
        searchService.updateQueryFragment("")
    }

    func selectLegRoute(legIndex: Int, routeIndex: Int) {
        guard routeLegs.indices.contains(legIndex) else { return }
        guard routeLegs[legIndex].routes.indices.contains(routeIndex) else { return }
        routeLegs[legIndex].selectedRouteIndex = routeIndex
        adjustCameraToFitRoute()
    }

    func selectNearestRoute(to coordinate: CLLocationCoordinate2D, drawerHeight: CGFloat = 280) {
        guard !routeLegs.isEmpty else { return }
        let tapMapPoint = MKMapPoint(coordinate)

        var bestLegIndex: Int?
        var bestRouteIndex: Int?
        var minDistance: Double = .greatestFiniteMagnitude

        for (legIndex, leg) in routeLegs.enumerated() {
            for (routeIndex, route) in leg.routes.enumerated() {
                let polyline = route.polyline
                let points = polyline.points()
                for pointIndex in 0..<polyline.pointCount {
                    let pt = points[pointIndex]
                    let dist = hypot(pt.x - tapMapPoint.x, pt.y - tapMapPoint.y)
                    if dist < minDistance {
                        minDistance = dist
                        bestLegIndex = legIndex
                        bestRouteIndex = routeIndex
                    }
                }
            }
        }

        // Proximity threshold roughly ~1000 map points depending on zoom
        if let lIndex = bestLegIndex, let rIndex = bestRouteIndex {
            if routeLegs[lIndex].selectedRouteIndex != rIndex {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.routeLegs[lIndex].selectedRouteIndex = rIndex
                }
            }
        }
    }

    // MARK: - Camera Framing
    /// Fits the camera to the whole route. The screen keeps its cards out of the map's safe area, so the map centers
    /// the route in the space between them.
    func adjustCameraToFitRoute(animation: Animation = .easeInOut(duration: 0.5)) {
        guard let polyline = combinedPolyline else { return }
        let framedRect = Self.FramingRect(around: polyline.boundingMapRect)

        withAnimation(animation) {
            self.cameraPosition = .rect(framedRect)
        }
    }

    /// How long the camera takes to travel to a new start point or route. A jump would show an empty map until the
    /// tiles of the far place were loaded; a travel loads them on the way.
    static let cameraFlight = Animation.easeInOut(duration: 1.5)

    /// Moves the camera to `position` as a flight instead of a jump.
    func FlyCamera(to position: MapCameraPosition) {
        withAnimation(Self.cameraFlight) {
            cameraPosition = position
        }
    }

    /// The map around one place, `area` meters across.
    static func View(of coordinate: CLLocationCoordinate2D, area: CLLocationDistance) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: area, longitudinalMeters: area))
    }

    /// A street-level view around one place.
    static func CloseUp(of coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
        View(of: coordinate, area: closeUpArea)
    }

    /// The route's bounds with the same margin on every side, so the route stays centered in the framed area.
    static func FramingRect(around routeRect: MKMapRect) -> MKMapRect {
        let horizontalMargin = routeRect.size.width * 0.15
        let verticalMargin = routeRect.size.height * 0.15
        return routeRect.insetBy(dx: -horizontalMargin, dy: -verticalMargin)
    }
}
