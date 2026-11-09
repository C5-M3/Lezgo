//
//  LiveLocationProviderTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

/// The conversion from a CoreLocation fix. The stream itself needs a real phone.
struct LiveLocationProviderTests {
    private func Fix(
        accuracy: CLLocationAccuracy,
        speed: CLLocationSpeed,
        course: CLLocationDirection = 90
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -7.2923, longitude: 112.7190),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            course: course,
            speed: speed,
            timestamp: TripFixtures.now
        )
    }

    /// The reading from a fix taken just now.
    private func Read(_ fix: CLLocation) -> LocationReading? {
        LiveLocationProvider.Reading(from: fix, now: TripFixtures.now)
    }

    @Test func GoodFixBecomesAReadingInKilometresPerHour() throws {
        let reading = try #require(Read(Fix(accuracy: 5, speed: 10)))

        #expect(reading.coordinate == TripFixtures.ciputraWorld)
        #expect(reading.speedKmh == 36)
        #expect(reading.recordedAt == TripFixtures.now)
    }

    @Test func UnknownSpeedCountsAsStandingStill() throws {
        let reading = try #require(Read(Fix(accuracy: 5, speed: -1)))

        #expect(reading.speedKmh == 0)
    }

    @Test func InvalidFixIsSkipped() {
        #expect(Read(Fix(accuracy: -1, speed: 10)) == nil)
    }

    @Test(arguments: [51.0, 101, 3_000])
    func RoughFixIsMarkedImprecise(accuracy: CLLocationAccuracy) throws {
        // With Precise Location off, every fix is kilometres wide: the sharer must know, to tell the person.
        let reading = try #require(Read(Fix(accuracy: accuracy, speed: 10)))

        #expect(reading.isPrecise == false)
    }

    @Test func FixWithinFiftyMetresIsPrecise() throws {
        let reading = try #require(Read(Fix(accuracy: 50, speed: 10)))

        #expect(reading.isPrecise)
    }

    @Test func FixOlderThanFiveSecondsIsSkipped() {
        let fix = Fix(accuracy: 5, speed: 10)

        #expect(LiveLocationProvider.Reading(from: fix, now: TripFixtures.now.addingTimeInterval(5)) != nil)
        #expect(LiveLocationProvider.Reading(from: fix, now: TripFixtures.now.addingTimeInterval(6)) == nil)
    }

    @Test func HeadingIsKeptInDegrees() throws {
        let reading = try #require(Read(Fix(accuracy: 5, speed: 10)))

        #expect(reading.course == 90)
    }

    @Test func UnknownHeadingIsNil() throws {
        let fix = Fix(accuracy: 5, speed: 10, course: -1)
        let reading = try #require(Read(fix))

        #expect(reading.course == nil)
    }

    @Test func NoFixIsSkipped() {
        #expect(LiveLocationProvider.Reading(from: nil) == nil)
    }
}
