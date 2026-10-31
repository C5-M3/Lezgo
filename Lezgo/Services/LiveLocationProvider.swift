//
//  LiveLocationProvider.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 27/10/26.
//

import CoreLocation
import Foundation

/// This phone's GPS readings from CoreLocation, tuned for driving.
///
/// While the stream is listened to, it keeps a `CLServiceSession` (asks for "When In Use" the first time, and for
/// precise location while Precise Location is off) and a `CLBackgroundActivitySession`, so readings keep coming with
/// the screen locked or another app in front (`UIBackgroundModes` has `location`). Readings without a fix or from
/// more than a few seconds ago are skipped; to the sharer that is the same as no signal. Rough readings are marked
/// imprecise, so the screens can say why this car is not shared.
final class LiveLocationProvider: LocationProvider {
    /// Readings less accurate than this (metres) are imprecise: a car drawn 100 m off sits on the wrong street.
    static let worstPreciseAccuracy: CLLocationAccuracy = 50
    /// The `NSLocationTemporaryUsageDescriptionDictionary` entry iOS shows when it asks for precise location.
    static let fullAccuracyPurposeKey = "TripLocation"
    /// Readings older than this (seconds) are skipped: CoreLocation can hand over a cached fix when updates start.
    static let maximumAge: TimeInterval = 5

    func Readings() -> AsyncStream<LocationReading> {
        AsyncStream { continuation in
            let task = Task {
                let session = CLServiceSession(
                    authorization: .whenInUse,
                    fullAccuracyPurposeKey: Self.fullAccuracyPurposeKey
                )
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

    /// A reading from a CoreLocation fix, or `nil` when there is no fix or it is too old at `now`. A rough fix is
    /// marked imprecise.
    static func Reading(from location: CLLocation?, now: Date = .now) -> LocationReading? {
        guard let location,
              location.horizontalAccuracy >= 0,
              now.timeIntervalSince(location.timestamp) <= maximumAge else {
            return nil
        }
        return LocationReading(
            coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            speedKmh: max(location.speed, 0) * 3.6,
            recordedAt: location.timestamp,
            course: location.course >= 0 ? location.course : nil,
            isPrecise: location.horizontalAccuracy <= worstPreciseAccuracy
        )
    }
}
