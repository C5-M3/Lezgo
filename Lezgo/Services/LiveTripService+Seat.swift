//
//  LiveTripService+Seat.swift
//  Lezgo
//
//  Created by Oky Faishal on 16/11/26.
//

import CloudKit
import Foundation

/// One iCloud account is in one trip at a time, kept in one seat record per account (ADR 0031).
extension LiveTripService {
    /// A phone in a trip reads the seat every this many polls (about every 3 seconds).
    static let seatPollEvery = 3

    func MyTrip() async throws -> TripSession? {
        try await Run {
            guard let seat = try await LiveSeat() else { return nil }
            let state = try await reader.LoadState(tripID: seat.tripID)
            return TripSession(myParticipantID: seat.participantID, state: state)
        }
    }

    func ResumeTrip(tripID: UUID, participantID: UUID) async throws -> TripSession {
        try await Run {
            let state = try await reader.LoadState(tripID: tripID)
            guard state.trip.status.isOpen else { throw TripServiceError.tripEnded }
            guard state.participants.contains(where: { $0.id == participantID }) else { throw TripServiceError.notFound }
            try await ClaimSeat(tripID: tripID, participantID: participantID)
            return TripSession(myParticipantID: participantID, state: state)
        }
    }

    func AccountID() async throws -> String {
        try await Run { TripSeat.AccountToken(forAccount: try await UserRecordName()) }
    }

    func SeatTakenOver(tripID: UUID) async {
        while heldSessions[tripID] == nil, Task.isCancelled == false {
            // This phone did not join the trip: there is no seat of its own to lose.
            try? await Task.sleep(for: .seconds(1))
        }
        while let mine = heldSessions[tripID], Task.isCancelled == false {
            try? await Task.sleep(for: pollInterval * Self.seatPollEvery)
            guard let seat = try? await SeatRecord().seat, seat.sessionID != mine else { continue }
            heldSessions[tripID] = nil
            return
        }
    }

    /// The account's seat when it is live: its trip is open and its participant is still in it. A seat that is not
    /// live counts as no seat, so nothing has to clean it up.
    func LiveSeat() async throws -> TripSeat? {
        guard let seat = try await SeatRecord().seat else { return nil }
        let tripRecordID = TripRecordMapper.RecordID(seat.tripID)
        let participantRecordID = TripRecordMapper.RecordID(seat.participantID)
        let records = try await database.Fetch([tripRecordID, participantRecordID])
        guard let tripRecord = records.first(where: { $0.recordID == tripRecordID }),
              let trip = try? TripRecordMapper.MakeTrip(from: tripRecord), trip.status.isOpen,
              let participantRecord = records.first(where: { $0.recordID == participantRecordID }),
              let participant = try? TripRecordMapper.MakeParticipant(from: participantRecord),
              participant.tripID == seat.tripID else { return nil }
        return seat
    }

    /// Takes the account's seat for this trip with a new session, saved only if nobody changed the seat since it was
    /// read. When two phones claim at the same moment, one save fails, and that phone reads the seat again.
    /// - Parameter records: the records this call's caller just saved for the trip; they are deleted when the claim
    ///   is refused, so a refused phone leaves nothing behind.
    /// - Throws: `.alreadyInTrip` when the account's live seat is for another trip.
    func ClaimSeat(tripID: UUID, participantID: UUID, undoingWith records: [CKRecord] = []) async throws {
        do {
            try await TakeSeat(TripSeat(tripID: tripID, participantID: participantID, sessionID: UUID()))
        } catch {
            try? await database.Delete(records.map(\.recordID))
            throw error
        }
    }

    private func TakeSeat(_ seat: TripSeat) async throws {
        let account = try await UserRecordName()
        for _ in 0..<Self.seatClaimAttempts {
            let current = try await SeatRecord()
            if let held = current.seat, held.tripID != seat.tripID, try await IsLive(held) {
                throw TripServiceError.alreadyInTrip
            }
            let record = current.record ?? TripRecordMapper.MakeSeatRecord(seat, forAccount: account)
            record["polyline"] = seat.bytes
            do {
                try await database.Save([record], savePolicy: .ifServerRecordUnchanged)
                heldSessions[seat.tripID] = seat.sessionID
                return
            } catch {
                guard TripServiceError(cloudKitError: error) == .conflict else { throw error }
            }
        }
        throw TripServiceError.conflict
    }

    private static let seatClaimAttempts = 3

    private func IsLive(_ seat: TripSeat) async throws -> Bool {
        try await LiveSeat() == seat
    }

    /// The account's seat record, fetched by ID, and the seat in it. A missing record means no seat.
    private func SeatRecord() async throws -> (record: CKRecord?, seat: TripSeat?) {
        let recordID = TripRecordMapper.SeatRecordID(forAccount: try await UserRecordName())
        let record = try await database.Fetch([recordID]).first
        return (record, record.flatMap(TripRecordMapper.MakeSeat))
    }
}
