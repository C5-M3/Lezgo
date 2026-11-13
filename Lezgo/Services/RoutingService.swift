//
//  RoutingService.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//

import Foundation
import MapKit

struct RouteOption: Identifiable, Equatable {
    let id: UUID
    let name: String
    let polylines: [MKPolyline]
    let combinedPolyline: MKPolyline
    let totalDistance: CLLocationDistance
    let totalDuration: TimeInterval

    init(
        id: UUID = UUID(),
        name: String,
        polylines: [MKPolyline],
        combinedPolyline: MKPolyline,
        totalDistance: CLLocationDistance,
        totalDuration: TimeInterval
    ) {
        self.id = id
        self.name = name
        self.polylines = polylines
        self.combinedPolyline = combinedPolyline
        self.totalDistance = totalDistance
        self.totalDuration = totalDuration
    }

    static func == (lhs: RouteOption, rhs: RouteOption) -> Bool {
        lhs.id == rhs.id
    }
}

struct RouteLeg: Identifiable, Equatable {
    let id: UUID
    let legIndex: Int
    let fromName: String
    let toName: String
    let routes: [MKRoute]
    var selectedRouteIndex: Int

    init(
        id: UUID = UUID(),
        legIndex: Int,
        fromName: String,
        toName: String,
        routes: [MKRoute],
        selectedRouteIndex: Int = 0
    ) {
        self.id = id
        self.legIndex = legIndex
        self.fromName = fromName
        self.toName = toName
        self.routes = routes
        self.selectedRouteIndex = selectedRouteIndex
    }

    var selectedRoute: MKRoute {
        guard routes.indices.contains(selectedRouteIndex) else {
            return routes[0]
        }
        return routes[selectedRouteIndex]
    }

    static func == (lhs: RouteLeg, rhs: RouteLeg) -> Bool {
        lhs.id == rhs.id && lhs.selectedRouteIndex == rhs.selectedRouteIndex
    }
}

/// Asks MapKit for the routes of each leg between the stops. MapKit allows only 50 directions requests a minute for
/// the whole app, so the service waits for the stops to settle, remembers the legs it has, and stops a calculation
/// that was replaced.
final class RoutingService: RouteCalculating {
    typealias LegFetcher = (CLLocationCoordinate2D, CLLocationCoordinate2D) async throws -> [MKRoute]

    private struct LegKey: Hashable {
        let sourceLatitude: Double
        let sourceLongitude: Double
        let destinationLatitude: Double
        let destinationLongitude: Double

        init(source: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) {
            sourceLatitude = source.latitude
            sourceLongitude = source.longitude
            destinationLatitude = destination.latitude
            destinationLongitude = destination.longitude
        }
    }

    /// The wait when MapKit refuses without saying for how long, and the longest wait taken from its answer.
    private static let defaultThrottleWait: TimeInterval = 30
    private static let longestThrottleWait: TimeInterval = 60
    /// Reordering a long route tries many orders; the legs of older ones are dropped rather than growing forever.
    private static let cacheLimit = 64

    private let debounce: Duration
    private let fetchLegRoutes: LegFetcher
    private var cachedLegRoutes: [LegKey: [MKRoute]] = [:]

    /// - Parameters:
    ///   - debounce: How long to wait before asking, so that stops dragged around several times cost one calculation.
    ///   - fetchLegRoutes: Asks for one leg's routes; tests pass a fake, the app asks MapKit.
    init(debounce: Duration = .milliseconds(500), fetchLegRoutes: LegFetcher? = nil) {
        self.debounce = debounce
        self.fetchLegRoutes = fetchLegRoutes ?? { try await Self.FetchFromMapKit(from: $0, to: $1) }
    }

    func calculateMultiStopLegs(points: [RoutePoint]) async throws -> [RouteLeg] {
        guard points.count >= 2 else {
            throw NSError(
                domain: "RoutingService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Need at least 2 points to route."]
            )
        }

        // A newer calculation cancels this one while it waits, so a burst of changes asks MapKit only once.
        if debounce > .zero { try await Task.sleep(for: debounce) }

        var legs: [RouteLeg] = []
        for index in 0..<(points.count - 1) {
            // Stops reordered again: stop asking MapKit for legs nobody will use, which also keeps the rate limit away.
            try Task.checkCancellation()
            let legRoutes = try await RoutesForLeg(
                from: points[index].coordinate,
                to: points[index + 1].coordinate
            )
            legs.append(RouteLeg(
                legIndex: index,
                fromName: points[index].name,
                toName: points[index + 1].name,
                routes: legRoutes,
                selectedRouteIndex: 0
            ))
        }

        return legs
    }

    /// The routes of one leg: the ones found before when the same two places come up again, otherwise MapKit's.
    private func RoutesForLeg(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> [MKRoute] {
        let key = LegKey(source: source, destination: destination)
        if let cached = cachedLegRoutes[key] { return cached }

        let routes: [MKRoute]
        do {
            routes = try await fetchLegRoutes(source, destination)
        } catch {
            throw Self.Translated(error)
        }
        if cachedLegRoutes.count >= Self.cacheLimit { cachedLegRoutes.removeAll() }
        cachedLegRoutes[key] = routes
        return routes
    }

    /// MapKit's "too many requests" becomes `RoutingError.throttled`; every other error stays as it is. MapKit says
    /// when it answers again under `timeUntilReset`, a key Apple does not document, so a missing one means a guess.
    private static func Translated(_ error: any Error) -> any Error {
        guard let mapKitError = error as? MKError, mapKitError.code == .loadingThrottled else { return error }
        let details = mapKitError.errorUserInfo["MKErrorGEOErrorUserInfo"] as? [String: Any]
        let seconds = (details?["timeUntilReset"] as? NSNumber)?.doubleValue ?? defaultThrottleWait
        return RoutingError.throttled(retryAfter: min(max(seconds, 1), longestThrottleWait))
    }

    private static func FetchFromMapKit(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> [MKRoute] {
        let request = MKDirections.Request()
        request.source = MKMapItem.Make(at: source)
        request.destination = MKMapItem.Make(at: destination)
        request.transportType = .automobile
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)
        // A replaced calculation must not leave its request running.
        let response = try await withTaskCancellationHandler {
            try await directions.calculate()
        } onCancel: {
            directions.cancel()
        }

        guard !response.routes.isEmpty else {
            let errorInfo = [NSLocalizedDescriptionKey: "No drivable route found for leg."]
            throw NSError(domain: "RoutingService", code: 404, userInfo: errorInfo)
        }
        return response.routes
    }
}
