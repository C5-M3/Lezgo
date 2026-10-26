/// Whether a car is moving. A car is stopped after speed 0 for 30 seconds.
/// The raw values are the strings stored in CloudKit.
enum MotionState: String, Hashable, Codable, CaseIterable {
    case driving
    case stopped
}
