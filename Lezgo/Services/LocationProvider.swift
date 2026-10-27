import Foundation

/// This phone's GPS readings while a trip is open.
///
/// `LiveLocationProvider` uses CoreLocation; tests use `MockLocationProvider`.
protocol LocationProvider {
    /// Readings as the phone gets them, until the listening task is cancelled. Gaps (no GPS signal) simply mean
    /// no new reading.
    func Readings() -> AsyncStream<LocationReading>
}
