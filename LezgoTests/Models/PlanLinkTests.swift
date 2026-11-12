//
//  PlanLinkTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The link "Create a trip" opens (`specs/UserStories.md` → US-08): `lezgo://plan?to=Malang`.
struct PlanLinkTests {
    @Test func MakeAndReadKeepThePlace() throws {
        let link = try #require(PlanLink.Make(destination: "Malang"))

        #expect(link.absoluteString == "lezgo://plan?to=Malang")
        #expect(PlanLink.Destination(from: link) == "Malang")
    }

    @Test func PlaceWithSpacesAndAccentsSurvives() throws {
        let link = try #require(PlanLink.Make(destination: "Pantai Parangtritis, Bantul"))

        #expect(PlanLink.Destination(from: link) == "Pantai Parangtritis, Bantul")
    }

    @Test func SpacesAroundThePlaceAreTrimmed() throws {
        let link = try #require(PlanLink.Make(destination: "  Malang \n"))

        #expect(PlanLink.Destination(from: link) == "Malang")
    }

    @Test func VeryLongPlaceIsCutTo100Characters() throws {
        let link = try #require(PlanLink.Make(destination: String(repeating: "a", count: 300)))

        #expect(PlanLink.Destination(from: link)?.count == 100)
    }

    @Test(arguments: ["", "   "])
    func EmptyPlaceMakesNoLink(destination: String) {
        #expect(PlanLink.Make(destination: destination) == nil)
    }

    @Test(arguments: [
        "lezgo://plan",
        "lezgo://plan?to=",
        "lezgo://join?code=897654",
        "https://example.com/plan?to=Malang"
    ])
    func OtherLinksHaveNoPlace(link: String) throws {
        let url = try #require(URL(string: link))

        #expect(PlanLink.Destination(from: url) == nil)
    }
}
