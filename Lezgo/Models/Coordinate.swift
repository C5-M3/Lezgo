import CoreLocation

/// A point on Earth, in degrees.
struct Coordinate: Hashable, Codable {
    var latitude: Double
    var longitude: Double

    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
