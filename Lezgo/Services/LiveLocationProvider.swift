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
/// While the stream is listened to, it keeps a `CLServiceSession` (asks for "When In Use" the first time, "Always"
/// on the trip map, and precise location while Precise Location is off) and, with "While Using the App" access on
/// the trip map, a background session through `BackgroundLocationKeeper`, so
/// readings keep coming with the screen locked or another app in front (`UIBackgroundModes` has `location`). The
/// background session is only kept with "While Using the App" access: "Always" access needs none, and none is kept
/// while access is off. Readings without a fix or from more than a few seconds ago are skipped; to the sharer that
/// is the same as no signal. Rough readings are marked imprecise, so the screens can say why this car is not shared.
final class LiveLocationProvider: LocationProvider {
    /// Readings less accurate than this (metres) are imprecise: a car drawn 100 m off sits on the wrong street.
    static let worstPreciseAccuracy: CLLocationAccuracy = 50
    /// Readings older than this (seconds) are skipped: CoreLocation can hand over a cached fix when updates start.
    static let maximumAge: TimeInterval = 5

    /// `true` only on the trip map, while the trip is on the road: the readings go on with the screen locked or
    /// another app in front, and iOS shows the location arrow meanwhile. Anywhere else the readings pause when the
    /// app leaves the screen: an app closed while a background session runs may be started again by iOS to carry on,
    /// so it keeps using the location after the person closed it.
    private let keepsRunningInBackground: Bool

    init(keepsRunningInBackground: Bool = false) {
        self.keepsRunningInBackground = keepsRunningInBackground
    }

    /// The access the stream asks for (ADR 0029). The trip map asks for "Always", so it can share with the screen
    /// locked without a background session and its location arrow; iOS asks the person only once, and with "While
    /// Using the App" the map keeps the background session. Other screens never need more than "While Using".
    static func Authorization(keepsRunningInBackground: Bool) -> CLServiceSession.AuthorizationRequirement {
        keepsRunningInBackground ? .always : .whenInUse
    }

    func Readings() -> AsyncStream<LocationReading> {
        let keepsRunningInBackground = keepsRunningInBackground
        return AsyncStream { continuation in
            let task = Task {
                // Without a full-accuracy purpose: asking for precise location "just this once" would ask again on
                // every launch. Imprecise readings are reported instead, and the screens point to Settings.
                let session = CLServiceSession(
                    authorization: Self.Authorization(keepsRunningInBackground: keepsRunningInBackground)
                )
                let background = keepsRunningInBackground ? BackgroundLocationKeeper() : nil
                // Only reads the access level: the updates come from `liveUpdates`.
                let authorization = CLLocationManager()
                // Decided now, while the map is on screen: iOS starts a background session only in the foreground.
                let status = authorization.authorizationStatus
                background?.Follow(
                    needsSession: BackgroundLocationKeeper.NeedsSession(
                        denied: status == .denied,
                        deniedGlobally: false,
                        restricted: status == .restricted,
                        isAuthorizedAlways: status == .authorizedAlways
                    )
                )
                defer {
                    background?.Stop()
                    session.invalidate()
                }
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                        // With access turned off the updates keep coming, marked denied, and access can change to
                        // "Always" mid-trip; the location arrow must not stay meanwhile (#316).
                        background?.Follow(
                            needsSession: BackgroundLocationKeeper.NeedsSession(
                                denied: update.authorizationDenied,
                                deniedGlobally: update.authorizationDeniedGlobally,
                                restricted: update.authorizationRestricted,
                                isAuthorizedAlways: authorization.authorizationStatus == .authorizedAlways
                            )
                        )
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
