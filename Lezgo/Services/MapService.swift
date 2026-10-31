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
    /// Set while Home wants the location; until then the GPS stays off.
    private var isWanted = false

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
        // Home asks because it wants the location: once the person allows it, the GPS starts.
        isWanted = true
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        isWanted = true
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        isWanted = false
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        // iOS reports the permission as soon as the manager exists, also when it starts the app in the background;
        // the GPS starts only while Home asked for it.
        if isAuthorized, isWanted {
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
