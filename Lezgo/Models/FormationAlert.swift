/// The silent alert a member's car currently has (`specs/UserStories.md` → US-06, "Formation alerts").
/// The raw values are the strings stored in CloudKit.
enum FormationAlert: String, Hashable, Codable, CaseIterable {
    case none
    case offRoute
    case passedCheckpoint
    case aheadOfLeader
}
