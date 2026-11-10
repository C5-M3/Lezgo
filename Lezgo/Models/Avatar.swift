//
//  Avatar.swift
//  Lezgo
//
//  Created by oky faishal on 05/11/26.
//

/// The mascot a car shows to the group (`specs/UserStories.md` → US-04, "Avatar").
///
/// Each avatar is a set of finished images told apart by asset name ("MainSelectedBlue", "OntripGlowBlue", …), so
/// the raw value is the part those names share. It is also the string stored in CloudKit and on the phone.
enum Avatar: String, Hashable, Codable, CaseIterable {
    case yellow = "Yellow"
    case blue = "Blue"
    case green = "Green"
    case pink = "Pink"
    case purple = "Purple"

    /// What a member starts a trip with: every avatar but the leader's yellow.
    static let memberAvatars: [Avatar] = allCases.filter { $0 != .yellow }

    /// The avatar every trip starts with: yellow for the leader, a random other one for a member.
    static func Default(isLeader: Bool) -> Avatar {
        guard isLeader == false else { return .yellow }
        // memberAvatars is a fixed, non-empty list, so randomElement() never returns nil.
        return memberAvatars.randomElement() ?? .blue
    }
}
