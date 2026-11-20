//
//  InMemoryTripService+Seat.swift
//  Lezgo
//
//  Created by Oky Faishal on 16/11/26.
//

import Foundation

/// One iCloud account is in one trip at a time, like `LiveTripService+Seat.swift` (ADR 0031).
extension InMemoryTripService {
    func MyTrip() async throws -> TripSession? {
        try ThrowSimulatedFailure()
        guard let seat = store.LiveSeat(forAccount: userRecordID), let state = store.trips[seat.tripID] else {
            return nil
        }
        return TripSession(myParticipantID: seat.participantID, state: state)
    }

    func ResumeTrip(tripID: UUID, participantID: UUID) async throws -> TripSession {
        try ThrowSimulatedFailure()
        guard let state = store.trips[tripID] else { throw TripServiceError.notFound }
        guard state.trip.status.isOpen else { throw TripServiceError.tripEnded }
        guard state.participants.contains(where: { $0.id == participantID }) else { throw TripServiceError.notFound }
        if let seat = store.LiveSeat(forAccount: userRecordID), seat.tripID != tripID {
            throw TripServiceError.alreadyInTrip
        }
        ClaimSeat(tripID: tripID, participantID: participantID)
        return TripSession(myParticipantID: participantID, state: state)
    }

    func AccountID() async throws -> String {
        try ThrowSimulatedFailure()
        return TripSeat.AccountToken(forAccount: userRecordID)
    }

    func SeatTakenOver(tripID: UUID) async {
        guard let mine = heldSessions[tripID] else {
            // This phone did not join the trip: there is no seat of its own to lose.
            while Task.isCancelled == false { try? await Task.sleep(for: .seconds(1)) }
            return
        }
        // Another trip in the seat is a later trip of this account, not a phone that took this trip over.
        for await seat in store.ListenToSeat(forAccount: userRecordID)
        where seat.tripID == tripID && seat.sessionID != mine {
            heldSessions[tripID] = nil
            return
        }
    }

    /// Takes the account's seat for this trip with a new session (the caller has checked it is free or this trip's).
    func ClaimSeat(tripID: UUID, participantID: UUID) {
        let seat = TripSeat(tripID: tripID, participantID: participantID, sessionID: UUID())
        store.SaveSeat(seat, forAccount: userRecordID)
        heldSessions[tripID] = seat.sessionID
    }
}
