//
//  MapViewModel.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import SwiftUI
import MapKit

@Observable
final class MapViewModel {
    private let routingService = RoutingService()
    let searchService = LocationSearchService()

    var startPoint: RoutePoint?
    var destinationPoint: RoutePoint?
    var route: MKRoute?

    var cameraPosition: MapCameraPosition = .automatic
    var isLoadingRoute: Bool = false
    var errorMessage: String?

    // Sheet presentation
    var activeSelectionSheet: ActivePointSelection?
    var searchQuery: String = ""

    func onSearchQueryChanged(_ newQuery: String) {
        searchService.updateQueryFragment(newQuery)
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
                    
                    // Reset modal search state
                    self.activeSelectionSheet = nil
                    self.searchQuery = ""
                    self.searchService.updateQueryFragment("")

                    // Automatically compute route once both ends are selected
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
