import Foundation

/// Decides whether a car is driving or stopped (`specs/UserStories.md` → US-06, "Car status").
///
/// A car is stopped after speed 0 for 30 seconds, so a short stop at a traffic light still counts as driving.
struct MotionStateDetector {
    /// How long the speed must stay at 0 before the car counts as stopped.
    static let stopAfter: TimeInterval = 30
    /// Below this speed (km/h) the car counts as standing still; GPS speed jitters around 0 when parked.
    static let standingSpeed: Double = 1

    /// A parked car at the start of a trip counts as stopped until it moves.
    private(set) var state: MotionState = .stopped
    /// When the car last went below `standingSpeed`, while it still counts as driving.
    private var standingSince: Date?

    /// The motion state after a new reading.
    mutating func Update(speedKmh: Double, at date: Date) -> MotionState {
        guard speedKmh < Self.standingSpeed else {
            state = .driving
            standingSince = nil
            return state
        }
        guard state == .driving else { return state }
        let since = standingSince ?? date
        standingSince = since
        if date.timeIntervalSince(since) >= Self.stopAfter {
            state = .stopped
        }
        return state
    }
}
