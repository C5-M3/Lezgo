//
//  TripMapViewModel+Types.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation

// The trip map's small state types, nested in `TripMapViewModel` (ADR 0019), kept here so the view model file stays
// within SwiftLint's file length.
extension TripMapViewModel {
    /// What the trip map camera follows.
    enum CameraMode: Hashable {
        /// The camera stays on this phone's car as it moves.
        case followMyCar
        /// The camera shows the whole route; it no longer moves with the car.
        case wholeRoute
        /// The person moved the map by hand; the camera stays where they left it.
        case free
    }

    /// The confirmation shown before leaving the trip from the map (`specs/UserStories.md` → US-07, "Leave and end").
    enum LeaveConfirmation: Hashable {
        /// A member: "Exit trip?"
        case exitTrip
        /// The leader: "End trip?", or "End trip? Not everyone has arrived yet." when someone is still on the way.
        case endTrip(everyoneHasArrived: Bool)
    }

    /// Why the trip map closed on this phone, which then returns to Home.
    enum CloseReason: Hashable {
        /// This member chose "Exit Trip".
        case exited
        /// This leader chose "End Trip".
        case ended
        /// Another phone, the leader's, ended the trip: "The leader ended the trip."
        case endedByLeader
        /// The leader removed this member: "You were removed from the trip."
        case removed
    }

    /// What the bottom card shows once this phone's car has arrived (`specs/UserStories.md` → US-07, "Arrive").
    enum ArrivalCard: Hashable {
        /// "You have arrived" · "Waiting for everyone to arrive"
        case waitingForEveryone
        /// "Everyone has arrived!" (and, for the leader, "Continue your trip?")
        case everyoneArrived
    }
}
