//
//  CLPlacemarkLezgoTests.swift
//  LezgoTests
//

import CoreLocation
import Testing
@testable import Lezgo

/// Before iOS 26 the address comes from `CLGeocoder`. These cases are the ones MapKit's `shortAddress` gave for the
/// same points in Surabaya and Malang, so both versions show the same text (ADR 0031).
struct CLPlacemarkLezgoTests {
    @Test func NameAndCityMakeTheShortAddress() {
        let address = CLPlacemark.ShortAddress(name: "Jalan Jenderal Basuki Rachmat No. 8", locality: "Surabaya")

        #expect(address == "Jalan Jenderal Basuki Rachmat No. 8, Surabaya")
    }

    @Test func PlaceWithoutAStreetUsesItsName() {
        let address = CLPlacemark.ShortAddress(name: "Rumah Sakit Darmo", locality: "Surabaya")

        #expect(address == "Rumah Sakit Darmo, Surabaya")
    }

    @Test func NameAloneIsTheShortAddress() {
        #expect(CLPlacemark.ShortAddress(name: "Malang City Square", locality: nil) == "Malang City Square")
    }

    @Test func CityAloneIsTheShortAddress() {
        #expect(CLPlacemark.ShortAddress(name: nil, locality: "Sidoarjo") == "Sidoarjo")
    }

    @Test(arguments: [(String?.none, String?.none), ("", ""), ("  ", nil)])
    func NothingKnownGivesNoShortAddress(name: String?, locality: String?) {
        #expect(CLPlacemark.ShortAddress(name: name, locality: locality) == nil)
    }
}
