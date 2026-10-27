import CoreLocation
import Foundation
import Testing
@testable import Lezgo

/// The conversion from a CoreLocation fix. The stream itself needs a real phone.
struct LiveLocationProviderTests {
    private func Fix(accuracy: CLLocationAccuracy, speed: CLLocationSpeed) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -7.2923, longitude: 112.7190),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            course: 90,
            speed: speed,
            timestamp: TripFixtures.now
        )
    }

    @Test func GoodFixBecomesAReadingInKilometresPerHour() throws {
        let reading = try #require(LiveLocationProvider.Reading(from: Fix(accuracy: 5, speed: 10)))

        #expect(reading.coordinate == TripFixtures.ciputraWorld)
        #expect(reading.speedKmh == 36)
        #expect(reading.recordedAt == TripFixtures.now)
    }

    @Test func UnknownSpeedCountsAsStandingStill() throws {
        let reading = try #require(LiveLocationProvider.Reading(from: Fix(accuracy: 5, speed: -1)))

        #expect(reading.speedKmh == 0)
    }

    @Test(arguments: [-1.0, 101, 500])
    func RoughOrInvalidFixIsSkipped(accuracy: CLLocationAccuracy) {
        #expect(LiveLocationProvider.Reading(from: Fix(accuracy: accuracy, speed: 10)) == nil)
    }

    @Test func NoFixIsSkipped() {
        #expect(LiveLocationProvider.Reading(from: nil) == nil)
    }
}
