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

final class RoutingService {
    func calculateMultiStopLegs(points: [RoutePoint]) async throws -> [RouteLeg] {
        guard points.count >= 2 else {
            throw NSError(
                domain: "RoutingService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Need at least 2 points to route."]
            )
        }

        var legs: [RouteLeg] = []
        for index in 0..<(points.count - 1) {
            let legRoutes = try await calculateLegRoutes(
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

    private func calculateLegRoutes(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> [MKRoute] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard !response.routes.isEmpty else {
            let errorInfo = [NSLocalizedDescriptionKey: "No drivable route found for leg."]
            throw NSError(domain: "RoutingService", code: 404, userInfo: errorInfo)
        }
        return response.routes
    }
}
