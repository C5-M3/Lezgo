//
//  TripActivityContentTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// What the trip's Live Activity says: the current leg, its time and its ends (ADR 0028).
@MainActor
struct TripActivityContentTests {
    private typealias Fixtures = TripMapFixtures
    private typealias Sample = TripActivityFixtures

    @Test func AttributesNameTheDestination() {
        #expect(TripActivityContent.Attributes(destinationName: "Pakuwon mall").title == "To Pakuwon mall")
    }

    @Test func FirstLegGoesFromTheStartToTheFirstStop() {
        let state = TripActivityContent.State(Sample.Input())
        #expect(state.stage == .driving)
        #expect(state.title == "To Ciputra World")
        #expect(state.legStartLabel == "Start")
        #expect(state.legEndLabel == "Stop 1 of 2")
    }

    @Test func NextLegStartsAtTheStopJustPassed() {
        let state = TripActivityContent.State(Sample.Input(currentWaypointIndex: 2))
        #expect(state.title == "To Rest area KM 57")
        #expect(state.legStartLabel == "Ciputra World")
        #expect(state.legEndLabel == "Stop 2 of 2")
    }

    @Test func LastLegEndsAtTheDestination() {
        let state = TripActivityContent.State(Sample.Input(currentWaypointIndex: 3))
        #expect(state.title == "To Pakuwon mall")
        #expect(state.legStartLabel == "Rest area KM 57")
        #expect(state.legEndLabel == "Destination")
    }

    @Test func TripWithoutStopsIsOneLeg() {
        let state = TripActivityContent.State(Sample.Input(waypoints: [Fixtures.startPoint, Fixtures.destination]))
        #expect(state.title == "To Pakuwon mall")
        #expect(state.legStartLabel == "Start")
        #expect(state.legEndLabel == "Destination")
    }

    @Test func LastLegShowsTheWholeTimeLeft() {
        let state = TripActivityContent.State(Sample.Input(currentWaypointIndex: 3))
        #expect(state.timeText == "1 hr, 20 min")
        #expect(state.shortTimeText == "1:20")
    }

    /// The routing service only knows the time to the destination, so the time to a stop is its share of the road.
    @Test func TimeToAStopIsItsShareOfTheTimeLeft() throws {
        let state = TripActivityContent.State(Sample.Input())
        let text = try #require(state.shortTimeText)
        #expect(text.hasSuffix(" min"))
        let minutes = try #require(Int(text.prefix { $0.isNumber }))
        #expect(minutes > 30 && minutes < 45)
        #expect(state.timeText == text)
    }

    @Test func DistanceToAStopIsMeasuredAlongTheRoad() throws {
        let state = TripActivityContent.State(Sample.Input())
        let text = try #require(state.distanceText)
        #expect(text.hasSuffix(" km"))
        let kilometres = try #require(Double(text.prefix { $0.isNumber || $0 == "." }))
        #expect(kilometres > 3 && kilometres < 5)
    }

    @Test func DistanceOnTheLastLegIsTheDistanceLeft() {
        var guidance = Fixtures.Guidance(minutesLeft: 80)
        guidance.distanceLeft = Measurement(value: 64, unit: .kilometers)
        let state = TripActivityContent.State(Sample.Input(guidance: guidance, currentWaypointIndex: 3))
        #expect(state.distanceText == "64 km")
    }

    @Test func ArrivedHasNoDistance() {
        let progress = TripMapArrivalProgress(robots: [], arrivedCount: 3, totalCount: 4)
        let state = TripActivityContent.State(
            Sample.Input(currentWaypointIndex: 3, arrivalCard: .waitingForEveryone, arrivalProgress: progress)
        )
        #expect(state.distanceText == nil)
    }

    @Test func NoGuidanceYetIsLoading() {
        let state = TripActivityContent.State(Sample.Input(guidance: nil))
        #expect(state.stage == .loading)
        #expect(state.timeText == nil)
        #expect(state.shortTimeText == nil)
        #expect(state.title == "To Ciputra World")
    }

    @Test func ArrivedShowsTheTitleCountAndWhatIsNext() {
        let progress = TripMapArrivalProgress(robots: [], arrivedCount: 3, totalCount: 4)
        let state = TripActivityContent.State(
            Sample.Input(currentWaypointIndex: 3, arrivalCard: .waitingForEveryone, arrivalProgress: progress)
        )
        #expect(state.stage == .arrived)
        #expect(state.title == "You have arrived")
        #expect(state.countText == "3/4")
        #expect(state.legStartLabel == "Waiting for everyone to arrive")
        #expect(state.legEndLabel == "Destination")
        #expect(state.timeText == nil)
    }

    @Test func MyRobotColourIsKnown() {
        #expect(TripActivityContent.State(Sample.Input()).myColor == .blue)
    }

    @Test func VeryLongStopNamesAreKeptWhole() {
        let name = "Rest area KM 57 Jalan Tol Jagorawi arah Puncak Bogor Jawa Barat"
        var stop = Fixtures.checkpoint
        stop.name = name
        let state = TripActivityContent.State(Sample.Input(waypoints: [Fixtures.startPoint, stop, Sample.lastStop]))
        #expect(state.title == "To \(name)")
    }
}
