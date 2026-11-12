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
                    self.adjustCameraToFitRoute(animation: Self.cameraFlight)
                }
            } catch {
                // A cancelled calculation belongs to an older order of the stops, so its failure is not the user's.
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    // The old line no longer matches the stops, so it goes.
                    self.routeLegs = []
                    self.routedPoints = []
                    self.isLoadingRoute = false
                    self.errorMessage = Self.RouteFailureMessage(for: error)
                }
                // MapKit will answer again after its minute is over; ask then, unless the stops changed meanwhile
                // (a change cancels this task, and asks on its own).
                if case RoutingError.throttled(let retryAfter) = error {
                    try? await Task.sleep(for: .seconds(retryAfter))
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self.findRoute() }
                }
            }
        }
    }

    static func RouteFailureMessage(for error: any Error) -> String {
        if case RoutingError.throttled = error { return "Too many route requests. Trying again in a moment." }
        return "Failed to calculate multi-stop route."
    }
}
