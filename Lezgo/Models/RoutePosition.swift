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
        guard let nearest = Nearest(to: point, on: polyline) else {
            return RoutePosition(distanceFromRoute: point.Distance(to: first), distanceAlongRoute: 0)
        }
        return RoutePosition(distanceFromRoute: nearest.distance, distanceAlongRoute: nearest.distanceAlongRoute)
    }

    /// The route from the point on it nearest `point` to its end: what is still ahead of a car, so the map can
    /// leave out the part already driven, as Apple Maps does.
    static func RouteAhead(of point: Coordinate, on polyline: [Coordinate]) -> [Coordinate] {
        guard let nearest = Nearest(to: point, on: polyline) else { return polyline }
        let start = polyline[nearest.legIndex]
        let end = polyline[nearest.legIndex + 1]
        let onRoute = Coordinate(
            latitude: start.latitude + (end.latitude - start.latitude) * nearest.fraction,
            longitude: start.longitude + (end.longitude - start.longitude) * nearest.fraction
        )
        return [onRoute] + polyline[(nearest.legIndex + 1)...]
    }

    /// The point on `polyline` nearest `point`: which leg it is on and how far along that leg (0 at its start, 1 at
    /// its end). `nil` for a route without a leg.
    private static func Nearest(to point: Coordinate, on polyline: [Coordinate]) -> NearestPoint? {
        var best: NearestPoint?
        var legStartAlongRoute: CLLocationDistance = 0
        for (index, (start, end)) in zip(polyline, polyline.dropFirst()).enumerated() {
            let leg = Offset(of: end, from: start)
            let car = Offset(of: point, from: start)
            let legLength = (leg.x * leg.x + leg.y * leg.y).squareRoot()
            let fraction = legLength > 0 ? min(max((car.x * leg.x + car.y * leg.y) / (legLength * legLength), 0), 1) : 0
            let gapX = car.x - leg.x * fraction
            let gapY = car.y - leg.y * fraction
            let distance = (gapX * gapX + gapY * gapY).squareRoot()
            if distance < best?.distance ?? .infinity {
                best = NearestPoint(
                    legIndex: index,
                    fraction: fraction,
                    distance: distance,
                    distanceAlongRoute: legStartAlongRoute + legLength * fraction
                )
            }
            legStartAlongRoute += legLength
        }
        return best
    }

    /// `point` in metres east (`x`) and north (`y`) of `origin`.
    private static func Offset(of point: Coordinate, from origin: Coordinate) -> (x: Double, y: Double) {
        let metresPerDegreeEast = metresPerDegree * cos(origin.latitude * .pi / 180)
        return (
            x: (point.longitude - origin.longitude) * metresPerDegreeEast,
            y: (point.latitude - origin.latitude) * metresPerDegree
        )
    }

    /// The point on a route nearest a car (see `Nearest(to:on:)`).
    private struct NearestPoint {
        var legIndex: Int
        var fraction: Double
        var distance: CLLocationDistance
        var distanceAlongRoute: CLLocationDistance
    }
}
