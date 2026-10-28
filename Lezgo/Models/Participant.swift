//
//  Participant.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// One person in a trip, which is also one car and one phone.
///
/// Whether they lead is not stored here: compare with `Trip.leaderParticipantID` through `IsLeader(in:)`.
struct Participant: Identifiable, Hashable, Codable {
    /// How long a phone may go without sending a location before it counts as offline.
    static let offlineAfter: TimeInterval = 120

    /// The CloudKit record name.
    let id: UUID
    var tripID: UUID
    /// The iCloud user. Unique per trip: joining again with the same account returns this record.
    var userRecordID: String
    var displayName: String
    var carDescription: String
    /// `nil` until the phone sends its first location.
    var coordinate: Coordinate?
    var speedKmh: Double
    var motionState: MotionState
    var alert: FormationAlert
    var lastSeenAt: Date

    func IsLeader(in trip: Trip) -> Bool {
        id == trip.leaderParticipantID
    }

    /// Online until the last location is older than 2 minutes; exactly 2 minutes is still online.
    func IsOnline(at date: Date) -> Bool {
        date.timeIntervalSince(lastSeenAt) <= Self.offlineAfter
    }

    /// Someone who just created or joined a trip: no location yet, stopped, no alert.
    /// - Parameter profile: `nil` uses "Member" plus the end of the iCloud user ID.
    static func Joining(
        tripID: UUID,
        userRecordID: String,
        profile: ParticipantProfile?,
        at date: Date
    ) -> Participant {
        let profile = profile ?? ParticipantProfile.Default(forUserRecordID: userRecordID)
        return Participant(
            id: UUID(),
            tripID: tripID,
            userRecordID: userRecordID,
            displayName: profile.displayName,
            carDescription: profile.carDescription,
            coordinate: nil,
            speedKmh: 0,
            motionState: .stopped,
            alert: .none,
            lastSeenAt: date
        )
    }
}
