//
//  ParticipantProfile.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// The name and car a person shows to the group.
struct ParticipantProfile: Codable, Hashable {
    /// The longest name the group sees (`specs/UserStories.md` → US-04).
    static let maximumNameLength = 30

    var displayName: String
    var carDescription: String

    /// `name` without spaces around it and at most 30 characters, or `nil` when nothing is left.
    static func CleanedName(_ name: String) -> String? {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumNameLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The profile of someone with no saved profile yet: "Member" plus the last 4 characters of their iCloud user ID.
    static func Default(forUserRecordID userRecordID: String) -> ParticipantProfile {
        ParticipantProfile(
            displayName: String(localized: .participantDefaultName(String(userRecordID.suffix(4)))),
            carDescription: ""
        )
    }
}
