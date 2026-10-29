//
//  LiveDirectionsService.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import MapKit

/// Asks MapKit for the driving path, leg by leg, through Set Route's `RoutingService`, and takes the fastest route of
/// each leg: on the road nobody picks between alternatives.
struct LiveDirectionsService: DirectionsService {
    func DrivingPath(through points: [Coordinate]) async throws -> [Coordinate] {
        let routePoints = points.map { RoutePoint(name: "", subtitle: "", coordinate: $0.locationCoordinate) }
        let legs = try await RoutingService().calculateMultiStopLegs(points: routePoints)
        return Self.Join(legs.map { Self.Coordinates(of: $0.selectedRoute.polyline) })
    }

    /// The legs as one line. Each leg starts where the one before ends, so that shared point is kept once.
    private static func Join(_ legs: [[Coordinate]]) -> [Coordinate] {
        legs.reduce(into: []) { path, leg in
            path.append(contentsOf: leg.first == path.last ? leg.dropFirst() : leg[...])
        }
    }

    private static func Coordinates(of polyline: MKPolyline) -> [Coordinate] {
        var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&points, range: NSRange(location: 0, length: polyline.pointCount))
        return points.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
