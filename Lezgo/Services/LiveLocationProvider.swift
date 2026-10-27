import CoreLocation
import Foundation

/// This phone's GPS readings from CoreLocation, tuned for driving.
///
/// While the stream is listened to, it keeps a `CLServiceSession` (asks for "When In Use" the first time) and a
/// `CLBackgroundActivitySession`, so readings keep coming with the screen locked or another app in front
/// (`UIBackgroundModes` has `location`). Readings without a fix or with poor accuracy are skipped; to the sharer
/// that is the same as no signal.
final class LiveLocationProvider: LocationProvider {
    /// Readings less accurate than this (metres) are skipped: too rough for a 20 m checkpoint check.
    static let worstAccuracy: CLLocationAccuracy = 100

    func Readings() -> AsyncStream<LocationReading> {
        AsyncStream { continuation in
            let task = Task {
                let session = CLServiceSession(authorization: .whenInUse)
                let background = CLBackgroundActivitySession()
                defer {
                    background.invalidate()
                    session.invalidate()
                }
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                        guard let reading = Self.Reading(from: update.location) else { continue }
                        continuation.yield(reading)
                    }
                } catch {
                    // The updates ended (for example, permission was turned off); the sharer keeps the last position.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// A reading from a CoreLocation fix, or `nil` when there is no fix or it is too rough.
    static func Reading(from location: CLLocation?) -> LocationReading? {
        guard let location,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= worstAccuracy else {
            return nil
        }
        return LocationReading(
            coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            speedKmh: max(location.speed, 0) * 3.6,
            recordedAt: location.timestamp
        )
    }
}
