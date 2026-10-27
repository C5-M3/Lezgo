/// What the bottom card shows once this phone's car has arrived (`specs/UserStories.md` → US-07, "Arrive").
enum TripMapArrivalCard: Hashable {
    /// "You have arrived" · "Waiting for everyone to arrive"
    case waitingForEveryone
    /// "Everyone has arrived!" (and, for the leader, "Continue your trip?")
    case everyoneArrived
}
