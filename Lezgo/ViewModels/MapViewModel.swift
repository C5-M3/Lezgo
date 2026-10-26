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
    private let routingService = RoutingService()
    let searchService = LocationSearchService()
    let locationService = LocationService()

    var startPoint: RoutePoint?
    var destinationPoint: RoutePoint?
    var route: MKRoute?

    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var isLoadingRoute: Bool = false
    var errorMessage: String?

    // Sheet presentation
    var activeSelectionSheet: ActivePointSelection?
    var searchQuery: String = ""

    init() {
        // Set default start point as soon as the first GPS coordinate arrives
        locationService.onFirstLocationFound = { [weak self] coord in
            guard let self = self else { return }
            if self.startPoint == nil {
                self.startPoint = RoutePoint(
                    name: "Current Location",
                    subtitle: "GPS Location",
                    coordinate: coord
                )
                // If destination was already selected, trigger route search
                if self.destinationPoint != nil {
                    self.findRoute()
                }
            }
        }
    }

    func onAppear() {
        locationService.requestPermission()
        // Automatically prompt the user for the destination first
        if destinationPoint == nil {
            activeSelectionSheet = .destination
        }
    }

    func onSearchQueryChanged(_ newQuery: String) {
        searchService.updateQueryFragment(newQuery)
    }

    func selectCurrentLocationAsStart() {
        guard let current = locationService.userLocation else { return }
        startPoint = RoutePoint(
            name: "Current Location",
            subtitle: "GPS Location",
            coordinate: current
        )
        activeSelectionSheet = nil
        searchQuery = ""
        searchService.updateQueryFragment("")

        if destinationPoint != nil {
            findRoute()
        }
    }

    func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        Task {
            do {
                let resolvedPoint = try await searchService.resolveLocation(from: completion)
                await MainActor.run {
                    if self.activeSelectionSheet == .start {
                        self.startPoint = resolvedPoint
                    } else if self.activeSelectionSheet == .destination {
                        self.destinationPoint = resolvedPoint
                    }

                    self.activeSelectionSheet = nil
                    self.searchQuery = ""
                    self.searchService.updateQueryFragment("")

                    if self.startPoint != nil && self.destinationPoint != nil {
                        self.findRoute()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not resolve place coordinate."
                }
            }
        }
    }

    func findRoute() {
        guard let start = startPoint, let end = destinationPoint else { return }
        isLoadingRoute = true
        errorMessage = nil

        Task {
            do {
                let computedRoute = try await routingService.calculateRoute(from: start.coordinate, to: end.coordinate)
                await MainActor.run {
                    self.route = computedRoute
                    self.isLoadingRoute = false
                    withAnimation(.easeInOut(duration: 0.6)) {
                        self.cameraPosition = .rect(computedRoute.polyline.boundingMapRect)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingRoute = false
                    self.errorMessage = "Failed to calculate driving route."
                }
            }
        }
    }
}
