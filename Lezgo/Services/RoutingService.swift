//
//  RoutingService.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import Foundation
import MapKit

final class RoutingService {
    func calculateRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let primaryRoute = response.routes.first else {
            throw NSError(domain: "RoutingService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No drivable routes found."])
        }

        return primaryRoute
    }
}
