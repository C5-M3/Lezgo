import Foundation

/// Who has arrived at the destination (`specs/UserStories.md` → US-07, "Arrive").
///
/// A car has arrived within 20 m of the destination. Offline members count as not arrived, members without a
/// position yet count as not arrived, and members who left are no longer in the trip, so they are not counted.
struct TripMapArrival: Hashable {
    /// The arrival radius around the destination, in metres.
    static let radius: Double = 20

    var hasArrived: Bool
    var everyoneHasArrived: Bool

    static func Check(_ state: TripState, myParticipantID: UUID, at date: Date) -> TripMapArrival {
        guard let destination = state.destination else {
            return TripMapArrival(hasArrived: false, everyoneHasArrived: false)
        }
        let isThere = { (participant: Participant) in
            guard let coordinate = participant.coordinate else { return false }
            return coordinate.Distance(to: destination.coordinate) <= radius
        }
        let hasArrived = state.participants.first { $0.id == myParticipantID }.map(isThere) ?? false
        let everyoneHasArrived = state.participants.isEmpty == false && state.participants.allSatisfy { participant in
            participant.IsOnline(at: date) && isThere(participant)
        }
        return TripMapArrival(hasArrived: hasArrived, everyoneHasArrived: everyoneHasArrived)
    }
}
