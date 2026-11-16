//
//  TripRecordMapper+Seat.swift
//  Lezgo
//
//  Created by Oky Faishal on 16/11/26.
//

import CloudKit
import Foundation

extension TripRecordMapper {
    /// The account's seat record (ADR 0031). It is a `Trail` record with a fixed name, so the schema stays as it is.
    /// The trip readers fetch a trip's footprint by ID (`TrailRecordID`) and never query `Trail`, so they never see
    /// it. Anyone who adds a `Trail` query must skip the names that end in `-seat`.
    static func SeatRecordID(forAccount userRecordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: TripSeat.RecordName(forAccount: userRecordName))
    }

    /// A new seat record. It has no `tripID` reference: the seat is claimed with IDs that already exist, and the
    /// payload names the trip.
    static func MakeSeatRecord(_ seat: TripSeat, forAccount userRecordName: String) -> CKRecord {
        let record = CKRecord(recordType: trailType, recordID: SeatRecordID(forAccount: userRecordName))
        record["polyline"] = seat.bytes
        return record
    }

    /// The seat in a record, or `nil` when the record is not a seat.
    static func MakeSeat(from record: CKRecord) -> TripSeat? {
        guard record.recordType == trailType, let bytes = record["polyline"] as? Data else { return nil }
        return TripSeat(bytes: bytes)
    }
}
