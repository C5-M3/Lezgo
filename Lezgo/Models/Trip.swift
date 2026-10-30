//
//  Trip.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// One group journey: one room code and one route at a time.
///
/// The leader is stored only here (`leaderParticipantID`), so a trip can never have two leaders.
struct Trip: Identifiable, Hashable, Codable {
    let id: UUID
    /// Six digits, numbers only, for example "897654".
    var roomCode: String
    var status: TripStatus
    var leaderParticipantID: UUID
    /// The next waypoint the group drives to. Waypoints with a lower `orderIndex` are visited.
    var currentWaypointIndex: Int
    /// Goes up by one with every new route; phones never go back to an older version.
    var routeVersion: Int
    var createdAt: Date
    var startedAt: Date?
    var endedAt: Date?

    /// Six plain digits (0-9). Joining and inviting both use this, so they always agree on what a code is.
    ///
    /// Other scripts' digits, such as "٨٩٧٦٥٤", are refused: they pass `isNumber` but no one can type them back in.
    static func IsValidRoomCode(_ roomCode: String) -> Bool {
        roomCode.count == 6 && roomCode.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
