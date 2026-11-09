//
//  DrivingDirectionsService.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 30/10/26.
//

import MapKit

/// Turn-by-turn driving directions through points in order, for `LiveTripMapNavigator`.
///
/// `LiveDrivingDirectionsService` asks MapKit; tests use `MockDrivingDirectionsService`.
protocol DrivingDirectionsService {
    /// Directions from the first point through every later one. Throws when MapKit finds no route or the network
    /// is down.
    func Directions(through points: [Coordinate]) async throws -> DrivingDirections
}

/// Asks MapKit for each leg and joins the legs into one list of steps, taking the fastest route of each leg: on the
/// road nobody picks between alternatives.
struct LiveDrivingDirectionsService: DrivingDirectionsService {
    struct NoRoute: Error {}

    func Directions(through points: [Coordinate]) async throws -> DrivingDirections {
        guard points.count >= 2 else { throw NoRoute() }
        var directions = DrivingDirections(steps: [], expectedTravelTime: 0)
        for (from, to) in zip(points, points.dropFirst()) {
            let route = try await FastestRoute(from: from, to: to)
            directions.steps += route.steps.map {
                DrivingDirections.Step(instruction: $0.instructions, path: Self.Coordinates(of: $0.polyline))
            }
            directions.expectedTravelTime += route.expectedTravelTime
        }
        return directions
    }

    private func FastestRoute(from source: Coordinate, to destination: Coordinate) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(latitude: source.latitude, longitude: source.longitude),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(latitude: destination.latitude, longitude: destination.longitude),
            address: nil
        )
        request.transportType = .automobile
        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
            throw NoRoute()
        }
        return route
    }

    private static func Coordinates(of polyline: MKPolyline) -> [Coordinate] {
        var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&points, range: NSRange(location: 0, length: polyline.pointCount))
        return points.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
