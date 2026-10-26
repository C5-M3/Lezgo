/// Whether a car is moving. A car is stopped after speed 0 for 30 seconds (decided by the sending phone, #95).
enum TripMapMotionState: Hashable {
    case driving
    case stopped
}
