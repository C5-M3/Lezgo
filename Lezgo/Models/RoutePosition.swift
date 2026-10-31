//
//  RoutePosition.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import CoreLocation

/// Where a point lies against a route line: how far it is from the line, and how far along the line the nearest
/// point on it is. The formation alerts compare these (`specs/UserStories.md` → US-06, "Formation alerts").
struct RoutePosition: Hashable {
    /// Metres from the nearest point on the route.
    var distanceFromRoute: CLLocationDistance
    /// Metres from the start of the route to that nearest point.
    var distanceAlongRoute: CLLocationDistance

    /// Metres per degree of latitude, close enough everywhere for distances of a few kilometres.
    private static let metresPerDegree = 111_320.0

    /// The position of `point` against `polyline`, or `nil` for an empty route.
    ///
    /// Each leg is measured on a flat map around its own start; over the length of a road leg the Earth's curve
    /// changes the result by far less than GPS noise.
    static func Locate(_ point: Coordinate, on polyline: [Coordinate]) -> RoutePosition? {
        guard let first = polyline.first else { return nil }
        var best = RoutePosition(distanceFromRoute: point.Distance(to: first), distanceAlongRoute: 0)
        var legStartAlongRoute: CLLocationDistance = 0
        for (start, end) in zip(polyline, polyline.dropFirst()) {
            let leg = Offset(of: end, from: start)
            let car = Offset(of: point, from: start)
            let legLength = (leg.x * leg.x + leg.y * leg.y).squareRoot()
            // How far along this leg the nearest point is, from 0 (its start) to 1 (its end).
            let fraction = legLength > 0 ? min(max((car.x * leg.x + car.y * leg.y) / (legLength * legLength), 0), 1) : 0
            let gapX = car.x - leg.x * fraction
            let gapY = car.y - leg.y * fraction
            let distanceFromLeg = (gapX * gapX + gapY * gapY).squareRoot()
            if distanceFromLeg < best.distanceFromRoute {
                best = RoutePosition(
                    distanceFromRoute: distanceFromLeg,
                    distanceAlongRoute: legStartAlongRoute + legLength * fraction
                )
            }
            legStartAlongRoute += legLength
        }
        return best
    }

    /// The route from the point nearest `point` to its end.
    static func RouteAhead(of point: Coordinate, on polyline: [Coordinate]) -> [Coordinate] {
        []
    }

    /// `point` in metres east (`x`) and north (`y`) of `origin`.
    private static func Offset(of point: Coordinate, from origin: Coordinate) -> (x: Double, y: Double) {
        let metresPerDegreeEast = metresPerDegree * cos(origin.latitude * .pi / 180)
        return (
            x: (point.longitude - origin.longitude) * metresPerDegreeEast,
            y: (point.latitude - origin.latitude) * metresPerDegree
        )
    }
}
