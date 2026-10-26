//
//  RoutingService.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import Foundation
import MapKit

struct ComputedTrip {
    let polylines: [MKPolyline]
    let combinedPolyline: MKPolyline
    let totalDistance: CLLocationDistance
    let totalDuration: TimeInterval
}

final class RoutingService {
    func calculateMultiStopRoute(points: [RoutePoint]) async throws -> ComputedTrip {
        guard points.count >= 2 else {
            throw NSError(domain: "RoutingService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Need at least 2 points to route."])
        }

        var polylines: [MKPolyline] = []
        var totalDistance: CLLocationDistance = 0
        var totalDuration: TimeInterval = 0
        var allCoordinates: [CLLocationCoordinate2D] = []

        for i in 0..<(points.count - 1) {
            let legRoute = try await calculateLeg(from: points[i].coordinate, to: points[i + 1].coordinate)
            polylines.append(legRoute.polyline)
            totalDistance += legRoute.distance
            totalDuration += legRoute.expectedTravelTime

            var legCoords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: legRoute.polyline.pointCount)
            legRoute.polyline.getCoordinates(&legCoords, range: NSRange(location: 0, length: legRoute.polyline.pointCount))
            allCoordinates.append(contentsOf: legCoords)
        }

        let combined = MKPolyline(coordinates: allCoordinates, count: allCoordinates.count)
        return ComputedTrip(
            polylines: polylines,
            combinedPolyline: combined,
            totalDistance: totalDistance,
            totalDuration: totalDuration
        )
    }

    private func calculateLeg(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw NSError(domain: "RoutingService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No drivable route found for leg."])
        }
        return route
    }
}

