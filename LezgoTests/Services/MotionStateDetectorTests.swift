import Foundation
import Testing
@testable import Lezgo

struct MotionStateDetectorTests {
    private let start = TripFixtures.now

    @Test func ParkedCarStartsStopped() {
        var detector = MotionStateDetector()

        #expect(detector.Update(speedKmh: 0, at: start) == .stopped)
    }

    @Test func MovingCarIsDriving() {
        var detector = MotionStateDetector()

        #expect(detector.Update(speedKmh: 40, at: start) == .driving)
    }

    @Test(arguments: [(seconds: 0.0, state: MotionState.driving), (29, .driving), (30, .stopped), (45, .stopped)])
    func CarStopsAfterThirtySecondsAtZero(seconds: TimeInterval, state: MotionState) {
        var detector = MotionStateDetector()
        _ = detector.Update(speedKmh: 40, at: start)
        _ = detector.Update(speedKmh: 0, at: start.addingTimeInterval(1))

        #expect(detector.Update(speedKmh: 0, at: start.addingTimeInterval(1 + seconds)) == state)
    }

    @Test func ShortStopAtALightStaysDriving() {
        var detector = MotionStateDetector()
        _ = detector.Update(speedKmh: 40, at: start)
        _ = detector.Update(speedKmh: 0, at: start.addingTimeInterval(1))
        _ = detector.Update(speedKmh: 20, at: start.addingTimeInterval(20))

        #expect(detector.Update(speedKmh: 0, at: start.addingTimeInterval(45)) == .driving)
    }

    @Test func GpsJitterWhileParkedCountsAsStandingStill() {
        var detector = MotionStateDetector()
        _ = detector.Update(speedKmh: 40, at: start)
        _ = detector.Update(speedKmh: 0.4, at: start.addingTimeInterval(1))

        #expect(detector.Update(speedKmh: 0.8, at: start.addingTimeInterval(31)) == .stopped)
    }

    @Test func StoppedCarDrivesAgainAtOnce() {
        var detector = MotionStateDetector()
        _ = detector.Update(speedKmh: 0, at: start)

        #expect(detector.Update(speedKmh: 15, at: start.addingTimeInterval(1)) == .driving)
    }
}
