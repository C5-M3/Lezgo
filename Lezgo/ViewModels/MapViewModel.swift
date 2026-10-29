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
    var tripService: any TripService
    let activeTripStorage: any ActiveTripStorage
    private let routingService: RoutingService
    let searchService: LocationFindService
    let locationService: LocationService

    // MARK: - Route Planning State
    var startPoint: RoutePoint?
    var destinations: [RoutePoint] = []

    // MARK: - Trip Creation & Navigation State (US-01 / Issues 154 & 156)
    var isCreatingTrip: Bool = false
    var createdTripSession: TripSession?
    var isNavigatingToTripRoom: Bool = false

    var isRouteComplete: Bool {
        startPoint != nil && !destinations.isEmpty
    }

    var canCreateTrip: Bool {
        isRouteComplete && !isLoadingRoute && !isCreatingTrip
    }

    var routeCoordinates: [Coordinate] {
        var coords: [Coordinate] = []
        for leg in routeLegs {
            let poly = leg.selectedRoute.polyline
            var legCoords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: poly.pointCount)
            poly.getCoordinates(&legCoords, range: NSRange(location: 0, length: poly.pointCount))
            coords.append(contentsOf: legCoords.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) })
        }
        if coords.isEmpty {
            if let start = startPoint {
                coords.append(Coordinate(latitude: start.coordinate.latitude, longitude: start.coordinate.longitude))
            }
            coords.append(contentsOf: destinations.map {
                Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
            })
        }
        return coords
    }

    // MARK: - Computed Trip & Map State
    var routeLegs: [RouteLeg] = []

    var selectedPolylines: [MKPolyline] {
        routeLegs.map { $0.selectedRoute.polyline }
    }

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

    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var isLoadingRoute: Bool = false
    var errorMessage: String?

    // MARK: - Modal Search Presentation State
    var activeSelectionSheet: ActivePointSelection?
    var searchQuery: String = ""

    init(
        tripService: (any TripService)? = nil,
        activeTripStorage: (any ActiveTripStorage)? = nil,
        routingService: RoutingService = RoutingService(),
        searchService: LocationFindService = LocationFindService(),
        locationService: LocationService = LocationService()
    ) {
        self.tripService = tripService ?? InMemoryTripService.fallback
        self.activeTripStorage = activeTripStorage ?? UserDefaultsActiveTripStorage()
        self.routingService = routingService
        self.searchService = searchService
        self.locationService = locationService

        // Automatically default the start point to the first GPS fix
        self.locationService.onFirstLocationFound = { [weak self] coord in
            guard let self = self else { return }
            if self.startPoint == nil {
                self.startPoint = RoutePoint(
                    name: "Current Location",
                    subtitle: "GPS Location",
                    coordinate: coord
                )
                // If the user already picked a destination, trigger route calculation immediately
                if !self.destinations.isEmpty {
                    self.findRoute()
                }
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
        startPoint = RoutePoint(
            name: "Current Location",
            subtitle: "GPS Location",
            coordinate: current
        )
        closeSearch()
        findRoute()
    }

    func selectSearchResult(_ item: SearchResultItem) {
        Task {
            do {
                let resolved = try await searchService.resolveLocation(from: item)
                await MainActor.run {
                    guard let active = self.activeSelectionSheet else { return }
                    switch active {
                    case .start:
                        self.startPoint = resolved
                    case .destination(let index):
                        if index < self.destinations.count {
                            self.destinations[index] = resolved
                        } else {
                            self.destinations.append(resolved)
                        }
                    }

                    self.closeSearch()
                    self.findRoute()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not resolve coordinates for this location."
                }
            }
        }
    }

    private func closeSearch() {
        activeSelectionSheet = nil
        searchQuery = ""
        searchService.updateQueryFragment("")
    }

    // MARK: - Route Calculation
    func findRoute(drawerHeight: CGFloat = 280) {
        var orderedPoints: [RoutePoint] = []
        if let start = startPoint { orderedPoints.append(start) }
        orderedPoints.append(contentsOf: destinations)

        guard orderedPoints.count >= 2 else {
            routeLegs = []
            return
        }

        isLoadingRoute = true
        errorMessage = nil

        Task {
            do {
                let legs = try await routingService.calculateMultiStopLegs(points: orderedPoints)
                await MainActor.run {
                    self.routeLegs = legs
                    self.isLoadingRoute = false
                    self.adjustCameraToFitRoute(bottomPadding: drawerHeight)
                }
            } catch {
                await MainActor.run {
                    self.isLoadingRoute = false
                    self.errorMessage = "Failed to calculate multi-stop route."
                }
            }
        }
    }

    func selectLegRoute(legIndex: Int, routeIndex: Int, drawerHeight: CGFloat = 280) {
        guard routeLegs.indices.contains(legIndex) else { return }
        guard routeLegs[legIndex].routes.indices.contains(routeIndex) else { return }
        routeLegs[legIndex].selectedRouteIndex = routeIndex
        adjustCameraToFitRoute(bottomPadding: drawerHeight)
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
    func adjustCameraToFitRoute(bottomPadding: CGFloat) {
        guard let polyline = combinedPolyline else { return }
        let baseRect = polyline.boundingMapRect

        // Standard horizontal and top margins
        let horizontalPadding = baseRect.size.width * 0.25
        let topPadding = baseRect.size.height * 0.20

        // Scale bottom padding relative to screen sheet height
        let bottomMapOffset = baseRect.size.height * Double(bottomPadding / 300.0)

        let paddedRect = MKMapRect(
            x: baseRect.origin.x - horizontalPadding,
            y: baseRect.origin.y - topPadding,
            width: baseRect.size.width + (horizontalPadding * 2),
            height: baseRect.size.height + topPadding + bottomMapOffset
        )

        withAnimation(.easeInOut(duration: 0.5)) {
            self.cameraPosition = .rect(paddedRect)
        }
    }
}

// MARK: - Trip Planning & Creation (US-01 / Issues 154 & 156)

extension MapViewModel {
    func MakeTripPlan() -> TripPlan? {
        guard let start = startPoint, !destinations.isEmpty else { return nil }

        var waypoints: [PlannedWaypoint] = []
        waypoints.append(PlannedWaypoint(
            kind: .start,
            name: start.name,
            coordinate: Coordinate(latitude: start.coordinate.latitude, longitude: start.coordinate.longitude)
        ))

        for (index, dest) in destinations.enumerated() {
            let isLast = (index == destinations.count - 1)
            waypoints.append(PlannedWaypoint(
                kind: isLast ? .destination : .checkpoint,
                name: dest.name,
                coordinate: Coordinate(latitude: dest.coordinate.latitude, longitude: dest.coordinate.longitude)
            ))
        }

        let plan = TripPlan(waypoints: waypoints, polyline: routeCoordinates)
        guard plan.isValid else { return nil }
        return plan
    }

    @discardableResult
    func CreateTrip() async -> TripSession? {
        guard let plan = MakeTripPlan() else {
            errorMessage = "Requires at least a valid start and destination point."
            return nil
        }

        isCreatingTrip = true
        errorMessage = nil

        do {
            let session = try await tripService.CreateTrip(plan: plan, profile: nil)
            let distanceStr = totalDistance > 0 ? String(format: "%.1f km", totalDistance / 1000) : nil
            let summary = ActiveTripSummary.From(session: session, distanceText: distanceStr)
            activeTripStorage.SaveActiveTrip(summary)

            self.createdTripSession = session
            self.isNavigatingToTripRoom = true
            self.isCreatingTrip = false
            return session
        } catch let serviceError as TripServiceError {
            self.errorMessage = String(localized: serviceError.message)
            self.isCreatingTrip = false
            return nil
        } catch {
            let serviceError = TripServiceError(cloudKitError: error)
            self.errorMessage = String(localized: serviceError.message)
            self.isCreatingTrip = false
            return nil
        }
    }
}
