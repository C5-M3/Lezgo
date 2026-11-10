//
//  ParticipantProfile.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// The name, car and avatar a person shows to the group.
struct ParticipantProfile: Codable, Hashable {
    var displayName: String
    var carDescription: String
    /// `nil` until the person picks one; a profile change without one keeps the current avatar. A new trip always
    /// starts with `Avatar.Default(isLeader:)` instead. Optional also lets profiles saved before avatars existed load.
    var avatar: Avatar?

    /// The profile of someone who has not typed a name: the name stays empty, and the app shows "Leader" or
    /// "Car 2" instead (see `TripState.DisplayName(of:)`).
    static let unnamed = ParticipantProfile(displayName: "", carDescription: "")
}
