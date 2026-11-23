//
//  TripRoomViewModel+StartTrip.swift
//  Lezgo
//
//  Created by Nathan on 23/11/26.
//

import Foundation

/// When the leader may start the trip, and what the confirmation asks first (`specs/UserStories.md` → US-05).
extension TripRoomViewModel {
    /// The leader may start alone; `startTripConfirmationTitle` asks first (US-05, "Leader alone").
    var canStartTrip: Bool {
        isCurrentUserLeader && !isStartingTrip && !hasTripStarted
    }

    /// True when the leader is the only car in the room, so starting means driving alone.
    var isLeaderAlone: Bool {
        guard isCurrentUserLeader, !participants.isEmpty else { return false }
        return participants.allSatisfy { $0.id == myParticipantID }
    }

    var isEveryoneReady: Bool {
        guard !participants.isEmpty else { return false }
        return participants.allSatisfy { IsParticipantReady($0) }
    }

    /// Being alone wins over "not yet ready": it is the bigger surprise, and the leader can see their own readiness.
    var startTripConfirmationTitle: String {
        if isLeaderAlone { return String(localized: "You are the only one in this trip. Start the trip alone?") }
        return isEveryoneReady
            ? String(localized: "Start Trip?")
            : String(localized: "Some participants are not yet ready, are you sure you want to start the trip?")
    }
}
