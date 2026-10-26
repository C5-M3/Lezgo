import Foundation

/// The name and car a person shows to the group.
struct ParticipantProfile: Hashable {
    var displayName: String
    var carDescription: String

    /// The profile of someone with no saved profile yet: "Member" plus the last 4 characters of their iCloud user ID.
    static func Default(forUserRecordID userRecordID: String) -> ParticipantProfile {
        ParticipantProfile(
            displayName: String(localized: .participantDefaultName(String(userRecordID.suffix(4)))),
            carDescription: ""
        )
    }
}
