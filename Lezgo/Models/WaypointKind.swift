/// The three kinds of waypoint. The raw values are the strings stored in CloudKit.
enum WaypointKind: String, Hashable, Codable, CaseIterable {
    case start
    case checkpoint
    case destination
}
