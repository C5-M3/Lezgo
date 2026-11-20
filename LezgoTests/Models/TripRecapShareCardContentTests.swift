//
//  TripRecapShareCardContentTests.swift
//  LezgoTests
//

import Foundation
import Testing
@testable import Lezgo

struct TripRecapShareCardContentTests {
    private func Content(distance: String = "60 km", cars: Int = 3, stops: Int? = 6) -> TripRecapShareCardContent {
        var recap = TripRecap.sample
        recap.distanceText = distance
        recap.participantCount = cars
        recap.numberOfStops = stops
        return TripRecapShareCardContent(recap: recap)
    }

    @Test func DistanceIsSplitIntoTheNumberAndItsUnit() {
        #expect(Content(distance: "60 km").distanceNumberText == "60")
        #expect(Content(distance: "60 km").distanceUnitText == "km")
        #expect(Content(distance: "67km").distanceNumberText == "67")
        #expect(Content(distance: "67km").distanceUnitText == "km")
        #expect(Content(distance: "850 m").distanceUnitText == "m")
        #expect(Content(distance: "12.5 km").distanceNumberText == "12.5")
    }

    @Test func DistanceThatIsNotANumberIsKeptWhole() {
        let content = Content(distance: "far")

        #expect(content.distanceNumberText == "far")
        #expect(content.distanceUnitText.isEmpty)
    }

    @Test func DateAlsoComesAsDayMonthYearWithDots() {
        #expect(Content().numericDateText == "08.10.2026")
    }

    @Test func CarsAndStopsAreCountedInWords() {
        #expect(Content(cars: 3, stops: 6).carsText == "3 cars")
        #expect(Content(cars: 1, stops: 1).carsText == "1 car")
        #expect(Content(cars: 3, stops: 6).stopsText == "6 stops")
        #expect(Content(cars: 1, stops: 1).stopsText == "1 stop")
    }

    @Test func StopsNumberIsJustTheNumber() {
        #expect(Content(stops: 6).stopsNumberText == "6")
        #expect(Content(stops: nil).stopsNumberText == "0")
    }

    @Test func TripWithoutStopsSaysSoInsteadOfLeavingItOut() {
        #expect(Content(stops: nil).stopsText == "0 stops")
    }

    @Test func RouteNamesTheStartAndTheDestinationWithoutTheStopCount() {
        #expect(Content().routeText == "Universitas Ciputra → Tunjungan Plaza")
    }

    @Test func RobotsAreTheParticipantsWithTheLeaderFirst() {
        #expect(Content().robots == [.yellow, .purple, .pink])
    }

    @Test func ACrowdShowsSixRobotsAndCountsTheRest() {
        var recap = TripRecap.sample
        recap.participants = nil
        recap.participantCount = 9
        recap.avatars = Array(repeating: .blue, count: 9)

        let content = TripRecapShareCardContent(recap: recap)

        #expect(content.robots.count == 6)
        #expect(content.hiddenRobotCount == 3)
    }
}
