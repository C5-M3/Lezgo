//
//  MapService.swift
//  Lezgo
//
//  Created by Rizal Pratama on 24/10/26.
//

import CoreLocation
import Foundation

/// Layanan untuk mengelola izin lokasi dan mendapatkan posisi terkini perangkat pengguna.
@Observable
@MainActor
final class MapService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    var userLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var errorMessage: String?

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    /// Asks only while the person has not answered yet. After "Allow Once", iOS sets the answer back to "not
    /// determined" at the next launch, so the question comes back then; "While Using the App" stops it.
    func requestLocationPermission() {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        userLocation = latestLocation
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
