//
//  LocationService.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//

import Foundation
import CoreLocation
import OSLog

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let logger = Logger(subsystem: "com.nathansudiara.Lezgo", category: "LocationService")
    private let locationManager = CLLocationManager()
    var userLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    var onFirstLocationFound: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.authorizationStatus = locationManager.authorizationStatus
    }

    /// Whether a fix is good enough to be the trip's start point. The first fixes after the GPS starts can be
    /// hundreds of metres wide, so with precise location the planner waits for a better one; without it, the rough
    /// fix is all there is.
    static func IsGoodForStartPoint(_ location: CLLocation, hasFullAccuracy: Bool) -> Bool {
        guard hasFullAccuracy else { return true }
        return location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100
    }

    func requestPermission() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            StartUpdating()
        }
    }

    /// Starts the GPS. It never asks for precise location "just this once": iOS forgets that answer as soon as the app
    /// goes to the background, so it would ask on every launch. When Precise Location is off, the Trip Room and the
    /// map say so with a button to Settings, where it is turned on for good.
    private func StartUpdating() {
        locationManager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            StartUpdating()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        self.userLocation = coordinate

        let hasFullAccuracy = manager.accuracyAuthorization == .fullAccuracy
        if let callback = onFirstLocationFound, Self.IsGoodForStartPoint(location, hasFullAccuracy: hasFullAccuracy) {
            callback(coordinate)
            self.onFirstLocationFound = nil // Fire once for initial default
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location update failed: \(error.localizedDescription, privacy: .public)")
    }
}
