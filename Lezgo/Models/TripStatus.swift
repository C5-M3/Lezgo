//
//  TripStatus.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

/// Where a trip is in its life (`specs/UserStories.md` → "Trip status").
///
/// The raw values are the strings stored in CloudKit.
enum TripStatus: String, Hashable, Codable, CaseIterable {
    /// In the Trip Room, before Start Trip.
    case lobby = "LOBBY"
    /// On the road.
    case inTrip = "IN_TRIP"
    /// The leader ended the trip on the road.
    case ended = "ENDED"
    /// The leader left the Trip Room before the trip started.
    case cancelled = "CANCELLED"

    /// Open trips can still be joined and changed: `LOBBY` and `IN_TRIP`.
    var isOpen: Bool {
        self == .lobby || self == .inTrip
    }
}
