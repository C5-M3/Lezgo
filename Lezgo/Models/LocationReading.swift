import Foundation

/// One GPS reading from this phone.
struct LocationReading: Hashable {
    var coordinate: Coordinate
    /// Speed in km/h, never negative: CoreLocation's "unknown" speed is read as 0.
    var speedKmh: Double
    var recordedAt: Date
}
