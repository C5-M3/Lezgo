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
    var intermediateStops: [RoutePoint] = []
    var destinationPoint: RoutePoint?

    var tripResult: ComputedTrip?
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var isLoadingRoute: Bool = false
    var errorMessage: String?

    var activeSelectionSheet: ActivePointSelection?
    var searchQuery: String = ""

    init() {
        locationService.onFirstLocationFound = { [weak self] coord in
            guard let self = self else { return }
            if self.startPoint == nil {
                self.startPoint = RoutePoint(
                    name: "Current Location",
                    subtitle: "GPS Location",
                    coordinate: coord
                )
                if self.destinationPoint != nil {
                    self.findRoute()
                }
            }
        }
    }

    func onAppear() {
        locationService.requestPermission()
        if destinationPoint == nil {
            activeSelectionSheet = .destination
        }
    }

    func addStop() {
        // Appends an empty placeholder stop and opens search immediately
        let newIndex = intermediateStops.count
        activeSelectionSheet = .stop(index: newIndex)
    }

    func removeStop(at index: Int) {
        guard intermediateStops.indices.contains(index) else { return }
        intermediateStops.remove(at: index)
        findRoute()
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
        closeSearch()
        findRoute()
    }

    func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        Task {
            do {
                let resolved = try await searchService.resolveLocation(from: completion)
                await MainActor.run {
                    guard let active = self.activeSelectionSheet else { return }
                    switch active {
                    case .start:
                        self.startPoint = resolved
                    case .stop(let index):
                        if index < self.intermediateStops.count {
                            self.intermediateStops[index] = resolved
                        } else {
                            self.intermediateStops.append(resolved)
                        }
                    case .destination:
                        self.destinationPoint = resolved
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

    func findRoute() {
        var orderedPoints: [RoutePoint] = []
        if let start = startPoint { orderedPoints.append(start) }
        orderedPoints.append(contentsOf: intermediateStops)
        if let dest = destinationPoint { orderedPoints.append(dest) }

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
                    withAnimation(.easeInOut(duration: 0.6)) {
                        self.cameraPosition = .rect(trip.combinedPolyline.boundingMapRect)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingRoute = false
                    self.errorMessage = "Failed to calculate multi-stop route."
                }
            }
        }
    }
}
