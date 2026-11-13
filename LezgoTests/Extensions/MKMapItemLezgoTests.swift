//
//  MKMapItemLezgoTests.swift
//  LezgoTests
//

import MapKit
import Testing
@testable import Lezgo

/// Runs on every iOS version in the test plan, so the iOS 26 path and the placemark path before it are both covered
/// (ADR 0031).
struct MKMapItemLezgoTests {
    @Test func ItemMadeAtACoordinateKeepsThatCoordinate() {
        let tunjunganPlaza = CLLocationCoordinate2D(latitude: -7.2626, longitude: 112.7398)

        let item = MKMapItem.Make(at: tunjunganPlaza)

        #expect(item.placeCoordinate.latitude == tunjunganPlaza.latitude)
        #expect(item.placeCoordinate.longitude == tunjunganPlaza.longitude)
    }
}
