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

    func requestPermission() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        self.userLocation = coordinate

        if let callback = onFirstLocationFound {
            callback(coordinate)
            self.onFirstLocationFound = nil // Fire once for initial default
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location update failed: \(error.localizedDescription, privacy: .public)")
    }
}
