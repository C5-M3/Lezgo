//
//  TripRecapPeopleTextTests.swift
//  LezgoTests
//

import Foundation
import Testing
@testable import Lezgo

/// The "3 people · 60 km" line on a recap card, which also has to read right for a leader who drove alone.
struct TripRecapPeopleTextTests {
    private func Text(cars: Int) -> String {
        var recap = TripRecap.sample
        recap.participantCount = cars
        recap.distanceText = "60 km"
        return String(localized: recap.peopleAndDistanceText)
    }

    @Test func OneCarIsOnePerson() {
        #expect(Text(cars: 1) == "1 person · 60 km")
    }

    @Test func SeveralCarsArePeople() {
        #expect(Text(cars: 3) == "3 people · 60 km")
    }
}
