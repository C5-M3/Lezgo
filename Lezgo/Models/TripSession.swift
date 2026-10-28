//
//  TripSession.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// The result of creating or joining a trip: the trip, and which participant is this phone.
struct TripSession: Hashable {
    /// This phone's participant. Keep it with the trip ID; every later call needs it.
    var myParticipantID: UUID
    var state: TripState
}
