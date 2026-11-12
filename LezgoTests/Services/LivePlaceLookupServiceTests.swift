//
//  LivePlaceLookupServiceTests.swift
//  LezgoTests
//

import Testing
@testable import Lezgo

/// How MapKit's answers become the card's address and the nearby chips. The lookups themselves need the network.
struct LivePlaceLookupServiceTests {
    private let center = Coordinate(latitude: -7.2900, longitude: 112.7340)

    @Test func StreetAndAreaAreSplitAtTheFirstComma() {
        let address = LivePlaceLookupService.MakeAddress(
            shortAddress: "Jl Raya Darmo No. 52, Wonokromo, Surabaya",
            name: "Some Building"
        )

        #expect(address == PlaceAddress(street: "Jl Raya Darmo No. 52", area: "Wonokromo, Surabaya"))
    }

    @Test func AddressWithoutAnAreaHasAnEmptyArea() {
        let address = LivePlaceLookupService.MakeAddress(shortAddress: "Jl Raya Darmo", name: nil)

        #expect(address == PlaceAddress(street: "Jl Raya Darmo", area: ""))
    }

    @Test func NameIsUsedWithoutAShortAddress() {
        let address = LivePlaceLookupService.MakeAddress(shortAddress: nil, name: "Taman Bungkul")

        #expect(address == PlaceAddress(street: "Taman Bungkul", area: ""))
    }

    @Test func NothingIsKnownWithoutAShortAddressOrAName() {
        #expect(LivePlaceLookupService.MakeAddress(shortAddress: nil, name: nil) == nil)
        #expect(LivePlaceLookupService.MakeAddress(shortAddress: "", name: "") == nil)
    }

    @Test func NearestPlacesComeFirstAndTheListIsCut() {
        let far = Place("Far", latitude: -7.2800)
        let near = Place("Near", latitude: -7.2899)
        let middle = Place("Middle", latitude: -7.2880)

        let places = LivePlaceLookupService.Closest(from: [far, near, middle], around: center, limit: 2)

        #expect(places.map(\.name) == ["Near", "Middle"])
    }

    @Test func PlacesWithTheSameNameAreListedOnce() {
        let first = Place("Tunjungan Plaza", latitude: -7.2899)
        let second = Place("Tunjungan Plaza", latitude: -7.2890)

        let places = LivePlaceLookupService.Closest(from: [first, second], around: center, limit: 5)

        #expect(places.count == 1)
    }

    private func Place(_ name: String, latitude: Double) -> NearbyPlace {
        NearbyPlace(name: name, subtitle: "", coordinate: Coordinate(latitude: latitude, longitude: 112.7340))
    }
}
