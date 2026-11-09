//
//  TripMapArrival.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation

/// Who has arrived at the destination (`specs/UserStories.md` → US-07, "Arrive").
///
/// A car has arrived within 20 m of the destination, or once its driver said so with "I've Arrived". Offline
/// members count as not arrived, except this phone's own car: its driver can see where they are. Members without a
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
        let isThere = { (participant: Participant) in IsThere(participant, at: destination) }
        let hasArrived = state.participants.first { $0.id == myParticipantID }.map(isThere) ?? false
        // The same rule as `ArrivedIDs`, so the top card's count and the bottom card always agree.
        let everyoneHasArrived = state.participants.isEmpty == false && state.participants.allSatisfy { participant in
            (participant.id == myParticipantID || participant.IsOnline(at: date)) && isThere(participant)
        }
        return TripMapArrival(hasArrived: hasArrived, everyoneHasArrived: everyoneHasArrived)
    }

    /// The cars at the destination, in the order of the participants. Offline cars do not count, except this phone's
    /// own car: the driver can see it has arrived, whatever the last location update says.
    static func ArrivedIDs(_ state: TripState, myParticipantID: UUID, at date: Date) -> [UUID] {
        guard let destination = state.destination else { return [] }
        return state.participants.filter { participant in
            guard IsThere(participant, at: destination) else { return false }
            return participant.id == myParticipantID || participant.IsOnline(at: date)
        }
        .map(\.id)
    }

    /// Within 20 m of the destination, or the driver said they arrived there. The stopped banner uses it too, so a
    /// car that has arrived is never also "stopped".
    static func IsThere(_ participant: Participant, at destination: Waypoint) -> Bool {
        if participant.arrivedAtWaypointID == destination.id { return true }
        guard let coordinate = participant.coordinate else { return false }
        return coordinate.Distance(to: destination.coordinate) <= radius
    }
}
