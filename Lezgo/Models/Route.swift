import Foundation

/// The road path of a trip. A new version replaces the old one.
struct Route: Identifiable, Hashable, Codable {
    let id: UUID
    var tripID: UUID
    var version: Int
    var polyline: [Coordinate]
}
