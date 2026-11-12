//
//  TripMapViewModel+Siri.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// What the trip map gives Siri (`specs/UserStories.md` → US-08): the answers to questions, and the two things Siri
/// can change.
extension TripMapViewModel {
    /// What Siri can say about the trip (US-08), or `nil` while the trip is loading or once the map has closed.
    func SiriAnswers() -> TripAnswers? {
        guard let state, closeReason == nil else { return nil }
        return TripAnswers(
            state: state,
            myParticipantID: myParticipantID,
            myCoordinate: myCoordinate,
            guidance: guidance,
            streets: carLookups.compactMapValues(\.street),
            now: clock()
        )
    }

    /// "Mute Lezgo" / "Unmute Lezgo": the same switch as the map's Mute button, so the map and CarPlay follow it.
    func SetMuted(_ muted: Bool) {
        sound.SetMuted(muted)
    }

    /// "I've arrived in Lezgo", after the driver said yes: saves it like the button does and says what happens next.
    /// A failed save is spoken, so the map does not also keep a message about it.
    func ArriveFromSiri(_ confirmation: TripMapManualArrival.Confirmation) async -> String {
        await manualArrival.Confirm(confirmation)
        guard manualArrival.errorMessage == nil else {
            manualArrival.DismissError()
            return TripAnswers.arrivalFailed
        }
        guard var arrived = state else { return TripAnswers.Arrived(everyoneHasArrived: false) }
        // The trip stream brings the saved arrival a moment later; count this car as arrived already.
        if let index = arrived.participants.firstIndex(where: { $0.id == myParticipantID }) {
            arrived.participants[index].arrivedAtWaypointID = confirmation.destinationID
        }
        let arrival = TripMapArrival.Check(arrived, myParticipantID: myParticipantID, at: updatedAt ?? .now)
        return TripAnswers.Arrived(everyoneHasArrived: arrival.everyoneHasArrived)
    }
}
