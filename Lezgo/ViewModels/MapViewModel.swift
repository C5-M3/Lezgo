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
    private let routingService = RoutingService()
    let searchService = LocationSearchService()
    let locationService = LocationService()

    // MARK: - Route Planning State
    var startPoint: RoutePoint?
    var destinations: [RoutePoint] = []

    // MARK: - Computed Trip & Map State
    var tripResult: ComputedTrip?
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var isLoadingRoute: Bool = false
    var errorMessage: String?

    // MARK: - Modal Search Presentation State
    var activeSelectionSheet: ActivePointSelection?
    var searchQuery: String = ""

    init() {
        // Automatically default the start point to the first GPS fix
        locationService.onFirstLocationFound = { [weak self] coord in
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
            tripResult = nil
            return
        }

        isLoadingRoute = true
        errorMessage = nil

        Task {
            do {
                let trip = try await routingService.calculateMultiStopRoute(points: orderedPoints)
                await MainActor.run {
                    self.tripResult = trip
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

    // MARK: - Camera Framing
    func adjustCameraToFitRoute(bottomPadding: CGFloat) {
        guard let trip = tripResult else { return }
        let baseRect = trip.combinedPolyline.boundingMapRect

        // Standard horizontal and top margins
        let horizontalPadding = baseRect.size.width * 0.25
        let topPadding = baseRect.size.height * 0.20
        
        // Scale bottom padding relative to screen sheet height
        // In MapKit points, 1 screen point is roughly equivalent across zoom levels when scaled to the rect
        let bottomMapOffset = baseRect.size.height * Double(bottomPadding / 300.0)

        let paddedRect = MKMapRect(
            x: baseRect.origin.x - horizontalPadding,
            y: baseRect.origin.y - topPadding,
            width: baseRect.size.width + (horizontalPadding * 2),
            // Lengthening the bottom pulls the camera focus upward above the sheet
            height: baseRect.size.height + topPadding + bottomMapOffset
        )

        withAnimation(.easeInOut(duration: 0.5)) {
            self.cameraPosition = .rect(paddedRect)
        }
    }

}

