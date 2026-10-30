//
//  LocationServiceTests.swift
//  LezgoTests
//
//  Created by Farrell Sudjatmiko on 28/10/26.
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

struct LocationServiceTests {
    @Test func InitialStateHasNotDeterminedStatusAndNoLocation() {
        let service = LocationService()
        #expect(service.userLocation == nil)
    }

    @Test func LocationManagerDidChangeAuthorizationUpdatesStatus() {
        let service = LocationService()
        let manager = CLLocationManager()

        service.locationManagerDidChangeAuthorization(manager)

        #expect(service.authorizationStatus == manager.authorizationStatus)
    }

    @Test func DidUpdateLocationsUpdatesUserLocation() {
        let service = LocationService()
        let manager = CLLocationManager()
        let coordinate = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        service.locationManager(manager, didUpdateLocations: [location])

        #expect(service.userLocation?.latitude == coordinate.latitude)
        #expect(service.userLocation?.longitude == coordinate.longitude)
    }

    @Test func DidUpdateLocationsFiresOnFirstLocationFoundOnce() {
        let service = LocationService()
        let manager = CLLocationManager()
        let firstCoord = CLLocationCoordinate2D(latitude: -6.2000, longitude: 106.8000)
        let secondCoord = CLLocationCoordinate2D(latitude: -6.3000, longitude: 106.9000)

        var callbackCount = 0
        var receivedCoord: CLLocationCoordinate2D?
        service.onFirstLocationFound = { coord in
            callbackCount += 1
            receivedCoord = coord
        }

        let firstLocation = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
        service.locationManager(manager, didUpdateLocations: [firstLocation])
        #expect(callbackCount == 1)
        #expect(receivedCoord?.latitude == firstCoord.latitude)
        #expect(receivedCoord?.longitude == firstCoord.longitude)
        #expect(service.onFirstLocationFound == nil)

        // Subsequent update should not trigger callback again
        let secondLocation = CLLocation(latitude: secondCoord.latitude, longitude: secondCoord.longitude)
        service.locationManager(manager, didUpdateLocations: [secondLocation])
        #expect(callbackCount == 1)
        #expect(service.userLocation?.latitude == secondCoord.latitude)
    }

    @Test func DidUpdateLocationsHandlesEmptyLocationsArrayGracefully() {
        let service = LocationService()
        let manager = CLLocationManager()

        service.locationManager(manager, didUpdateLocations: [])

        #expect(service.userLocation == nil)
    }

    @Test func DidFailWithErrorDoesNotCrash() {
        let service = LocationService()
        let manager = CLLocationManager()
        let error = NSError(domain: "kCLErrorDomain", code: 0, userInfo: nil)

        service.locationManager(manager, didFailWithError: error)

        #expect(service.userLocation == nil)
    }
}
