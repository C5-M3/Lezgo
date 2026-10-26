import CoreLocation

/// A point on the trip map, in degrees.
///
/// The trip map keeps its own value types (`TripMap…`) so it can be built before the shared trip models (#64)
/// land. When they do, one adapter turns `Trip`, `Waypoint`, `Participant` and `Route` into a `TripMapSnapshot`,
/// and nothing else in the trip map changes.
struct TripMapCoordinate: Hashable {
    var latitude: Double
    var longitude: Double

    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Straight-line distance in metres, measured on the Earth's surface.
    func Distance(to other: TripMapCoordinate) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
