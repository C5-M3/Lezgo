/// Why the trip map closed on this phone, which then returns to Home.
enum TripMapCloseReason: Hashable {
    /// This member chose "Exit Trip".
    case exited
    /// This leader chose "End Trip".
    case ended
    /// Another phone, the leader's, ended the trip: "The leader ended the trip."
    case endedByLeader
    /// The leader removed this member: "You were removed from the trip."
    case removed
}
