//
//  LiveStreetNameServiceTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Testing
@testable import Lezgo

/// Which of MapKit's names the car status card shows. The lookup itself needs the network. The examples are what
/// MapKit returned on the sample route in Surabaya.
struct LiveStreetNameServiceTests {
    /// Next to a building, MapKit names the building; its short address still names the street.
    @Test func StreetIsPreferredOverTheNameOfABuilding() {
        let street = LiveStreetNameService.StreetName(
            shortAddress: "Jl Kencanasari Barat VII No. L-17 A, Surabaya",
            name: "Ciputra World Surabaya"
        )

        #expect(street == "Jl Kencanasari Barat VII")
    }

    /// The city is the same for every car in the trip, so it only makes the card longer.
    @Test func CityIsLeftOut() {
        let street = LiveStreetNameService.StreetName(
            shortAddress: "Jalan Raya Diponegoro No. 215, Surabaya",
            name: nil
        )

        #expect(street == "Jalan Raya Diponegoro")
    }

    /// The status line says where the car is, not which house: the street number is left out.
    @Test(arguments: [
        ("Jalan Tegal Sari No. 28, Surabaya", "Jalan Tegal Sari"),
        ("Jl Mayjend Sungkono no 5, Surabaya", "Jl Mayjend Sungkono"),
        ("Jl HR Mayjend Muhammad Nomor 12A, Surabaya", "Jl HR Mayjend Muhammad"),
        ("Jl Adityawarman, Surabaya", "Jl Adityawarman")
    ])
    func StreetNumberIsLeftOut(shortAddress: String, expected: String) {
        #expect(LiveStreetNameService.StreetName(shortAddress: shortAddress, name: nil) == expected)
    }

    @Test func NameIsUsedWhenOnlyANumberIsLeft() {
        let street = LiveStreetNameService.StreetName(shortAddress: "No. 28, Surabaya", name: "Tunjungan Plaza")

        #expect(street == "Tunjungan Plaza")
    }

    @Test func NameIsUsedWithoutAShortAddress() {
        let street = LiveStreetNameService.StreetName(shortAddress: nil, name: "Bukit Darmo Golf")

        #expect(street == "Bukit Darmo Golf")
    }

    @Test(arguments: ["", " , Surabaya"])
    func NameIsUsedWhenTheShortAddressHasNoStreet(shortAddress: String) {
        let street = LiveStreetNameService.StreetName(shortAddress: shortAddress, name: "Tunjungan Plaza")

        #expect(street == "Tunjungan Plaza")
    }

    @Test func NoNameWithoutEither() {
        #expect(LiveStreetNameService.StreetName(shortAddress: nil, name: nil) == nil)
    }
}
