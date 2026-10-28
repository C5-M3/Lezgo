/// The confirmation shown before leaving the trip from the map (`specs/UserStories.md` → US-07, "Leave and end").
enum TripMapLeaveConfirmation: Hashable {
    /// A member: "Exit trip?"
    case exitTrip
    /// The leader: "End trip?", or "End trip? Not everyone has arrived yet." when someone is still on the way.
    case endTrip(everyoneHasArrived: Bool)
}
