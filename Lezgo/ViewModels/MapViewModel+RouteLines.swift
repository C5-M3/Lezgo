//
//  MapViewModel+RouteLines.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import MapKit

extension MapViewModel {
    /// The chosen route of each leg as drawn on the map, joined to the stops it runs between so the line does not
    /// stop short of its pins. While the route is still for other stops, the legs are drawn as Apple gave them.
    var selectedRouteLines: [[Coordinate]] {
        let lines = routeLegs.map { Self.Coordinates(of: $0.selectedRoute.polyline) }
        let currentPoints = [startPoint].compactMap(\.self) + destinations
        guard routedPoints == currentPoints, routedPoints.count == lines.count + 1 else { return lines }
        return lines.enumerated().map { index, line in
            RouteLineEnds.Joined(
                line,
                from: Self.Coordinate(of: routedPoints[index]),
                to: Self.Coordinate(of: routedPoints[index + 1])
            )
        }
    }

    fileprivate static func Coordinates(of polyline: MKPolyline) -> [Coordinate] {
        var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&points, range: NSRange(location: 0, length: polyline.pointCount))
        return points.map { Lezgo.Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }

    fileprivate static func Coordinate(of point: RoutePoint) -> Lezgo.Coordinate {
        Lezgo.Coordinate(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
    }
}
