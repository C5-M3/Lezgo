import Foundation

/// Decides whether a car is driving or stopped (`specs/UserStories.md` → US-06, "Car status").
///
/// A car is stopped after speed 0 for 30 seconds, so a short stop at a traffic light still counts as driving.
struct MotionStateDetector {
    /// How long the speed must stay at 0 before the car counts as stopped.
    static let stopAfter: TimeInterval = 30
    /// Below this speed (km/h) the car counts as standing still; GPS speed jitters around 0 when parked.
    static let standingSpeed: Double = 1

    private(set) var state: MotionState = .stopped

    /// The motion state after a new reading.
    mutating func Update(speedKmh: Double, at date: Date) -> MotionState {
        state
    }
}
