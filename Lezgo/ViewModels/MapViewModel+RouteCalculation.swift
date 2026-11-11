//
//  MapViewModel+RouteCalculation.swift
//  Lezgo
//

import MapKit

extension MapViewModel {
    func findRoute() {
        var orderedPoints: [RoutePoint] = []
        if let start = startPoint { orderedPoints.append(start) }
        orderedPoints.append(contentsOf: destinations)

        routeTask?.cancel()
        guard orderedPoints.count >= 2 else {
            routeLegs = []
            routedPoints = []
            return
        }

        isLoadingRoute = true
        errorMessage = nil

        routeTask = Task {
            do {
                let legs = try await routingService.calculateMultiStopLegs(points: orderedPoints)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.routeLegs = legs
                    self.routedPoints = orderedPoints
                    self.isLoadingRoute = false
                    self.adjustCameraToFitRoute()
                }
            } catch {
                // A cancelled calculation belongs to an older order of the stops, so its failure is not the user's.
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    // The old line no longer matches the stops, so it goes.
                    self.routeLegs = []
                    self.routedPoints = []
                    self.isLoadingRoute = false
                    self.errorMessage = "Failed to calculate multi-stop route."
                }
            }
        }
    }
}
