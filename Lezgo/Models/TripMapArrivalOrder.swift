//
//  TripMapArrivalOrder.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation

/// The cars at the destination, in the order they got there.
///
/// The trip does not store when a car arrived, so each phone remembers the order it saw. A phone that opens the map
/// later starts from the order of the participants.
struct TripMapArrivalOrder: Hashable {
    /// The arrived cars, first one first.
    private(set) var ids: [UUID] = []

    /// Removes the cars that are no longer there and adds the new ones at the end.
    mutating func Update(_ state: TripState, myParticipantID: UUID, at date: Date) {
        let arrived = TripMapArrival.ArrivedIDs(state, myParticipantID: myParticipantID, at: date)
        ids.removeAll { arrived.contains($0) == false }
        ids.append(contentsOf: arrived.filter { ids.contains($0) == false })
    }
}
