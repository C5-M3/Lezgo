//
//  LocationFindServiceTests.swift
//  LezgoTests
//
//  Created by Farrell Sudjatmiko on 28/10/26.
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import Lezgo

struct LocationFindServiceTests {
    @Test func SearchResultItemEquatableAndHashable() {
        let item1 = SearchResultItem(
            id: "place_1",
            title: "Place One",
            subtitle: "123 Street",
            completion: nil,
            coordinate: CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8),
            distanceInMeters: 500,
            isCalculatingDistance: false
        )

        let item2 = SearchResultItem(
            id: "place_1",
            title: "Different Title Same ID",
            subtitle: "Different Subtitle",
            completion: nil,
            coordinate: nil,
            distanceInMeters: nil,
            isCalculatingDistance: true
        )

        let item3 = SearchResultItem(
            id: "place_2",
            title: "Place Two",
            subtitle: "456 Avenue",
            completion: nil,
            coordinate: nil,
            distanceInMeters: nil,
            isCalculatingDistance: false
        )

        #expect(item1 == item2)
        #expect(item1 != item3)

        var set: Set<SearchResultItem> = []
        set.insert(item1)
        #expect(set.contains(item2))
        #expect(!set.contains(item3))
    }

    @Test func UpdateQueryFragmentWithEmptyStringResetsState() {
        let service = LocationFindService()
        service.searchResults = [
            SearchResultItem(
                id: "test",
                title: "Test",
                subtitle: "Test Subtitle",
                completion: nil
            )
        ]
        service.isSearching = true

        service.updateQueryFragment("")

        #expect(service.searchResults.isEmpty)
        #expect(service.isSearching == false)
    }

    @Test func UpdateQueryFragmentWithWhitespaceOnlyResetsState() {
        let service = LocationFindService()
        service.searchResults = [
            SearchResultItem(
                id: "test",
                title: "Test",
                subtitle: "Test Subtitle",
                completion: nil
            )
        ]
        service.isSearching = true

        service.updateQueryFragment("   \n\t  ")

        #expect(service.searchResults.isEmpty)
        #expect(service.isSearching == false)
    }

    @Test func UpdateQueryFragmentSetsSearchingAndReferenceLocation() {
        let service = LocationFindService()
        let ref = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)

        service.updateQueryFragment("Monas", referenceLocation: ref)

        #expect(service.isSearching == true)
        #expect(service.referenceLocation?.latitude == ref.latitude)
        #expect(service.referenceLocation?.longitude == ref.longitude)
    }

    @Test func CompleterDidFailWithErrorClearsResultsAndStopsSearching() {
        let service = LocationFindService()
        service.searchResults = [
            SearchResultItem(
                id: "test",
                title: "Test",
                subtitle: "Test Subtitle",
                completion: nil
            )
        ]
        service.isSearching = true

        let completer = MKLocalSearchCompleter()
        let error = NSError(domain: "MKErrorDomain", code: 1, userInfo: nil)
        service.completer(completer, didFailWithError: error)

        #expect(service.searchResults.isEmpty)
        #expect(service.isSearching == false)
    }

    @Test func ResolveLocationReturnsRoutePointDirectlyWhenCoordinateIsCached() async throws {
        let service = LocationFindService()
        let coord = CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272)
        let item = SearchResultItem(
            id: "monas_jakarta",
            title: "Monas",
            subtitle: "Gambir, Jakarta Pusat",
            completion: nil,
            coordinate: coord
        )

        let point = try await service.resolveLocation(from: item)

        #expect(point.name == item.title)
        #expect(point.subtitle == item.subtitle)
        #expect(point.coordinate.latitude == coord.latitude)
        #expect(point.coordinate.longitude == coord.longitude)
    }
}
