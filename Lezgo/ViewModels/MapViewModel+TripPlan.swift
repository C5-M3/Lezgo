//
//  MapViewModel+TripPlan.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 29/10/26.
//

import MapKit

// Edit Route reuses the Set Route planner (`specs/UserStories.md` → US-06, "Route changes"): it opens with the rest
// of the trip's route and hands the changed route back as a `TripPlan`.
extension MapViewModel {
    /// The planner opened on the road: the first waypoint is the start point, the rest are the stops in order.
    convenience init(startingWaypoints: [PlannedWaypoint]) {
        self.init()
        let points = startingWaypoints.map {
            RoutePoint(name: $0.name, subtitle: "", coordinate: $0.coordinate.locationCoordinate)
        }
        startPoint = points.first
        destinations = Array(points.dropFirst())
    }

    /// The route on the map as a trip route: the start point, the stops as checkpoints and the last stop as the
    /// destination. `nil` until a route for the current stops is ready, so a line through an old stop is never saved.
    func MakeTripPlan() -> TripPlan? {
        guard isLoadingRoute == false, let startPoint, let lastStop = destinations.last,
              routedPoints == [startPoint] + destinations,
              let polyline = combinedPolyline else { return nil }
        let checkpoints = destinations.dropLast().map { PlannedWaypoint(point: $0, kind: .checkpoint) }
        let waypoints = [PlannedWaypoint(point: startPoint, kind: .start)] + checkpoints
            + [PlannedWaypoint(point: lastStop, kind: .destination)]
        return TripPlan(waypoints: waypoints, polyline: Self.Coordinates(of: polyline))
    }

    private static func Coordinates(of polyline: MKPolyline) -> [Coordinate] {
        var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&points, range: NSRange(location: 0, length: polyline.pointCount))
        return points.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

private extension PlannedWaypoint {
    init(point: RoutePoint, kind: WaypointKind) {
        self.init(
            kind: kind,
            name: point.name,
            coordinate: Coordinate(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
        )
    }
}
