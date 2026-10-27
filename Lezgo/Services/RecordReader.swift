//
//  RecordReader.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import CloudKit
import Foundation

/// Reads typed fields from a CloudKit record, and names the field when one is missing or has the wrong type.
struct RecordReader {
    private let record: CKRecord

    /// - Throws: `InvalidTripRecord` with field `recordType` when the record is of another type.
    init(_ record: CKRecord, expectedType: String) throws {
        guard record.recordType == expectedType else {
            throw InvalidTripRecord(recordType: expectedType, field: "recordType")
        }
        self.record = record
    }

    /// The model's ID, taken from the record name.
    func ID() throws -> UUID {
        guard let id = UUID(uuidString: record.recordID.recordName) else { throw Invalid("recordName") }
        return id
    }

    /// The ID of the trip a child record points to.
    func TripID() throws -> UUID {
        guard let reference = record["tripID"] as? CKRecord.Reference,
              let tripID = UUID(uuidString: reference.recordID.recordName) else {
            throw Invalid("tripID")
        }
        return tripID
    }

    func Value<Value>(_ field: String) throws -> Value {
        guard let value = record[field] as? Value else { throw Invalid(field) }
        return value
    }

    func OptionalValue<Value>(_ field: String) -> Value? {
        record[field] as? Value
    }

    func Integer(_ field: String) throws -> Int {
        guard let number = record[field] as? Int64 else { throw Invalid(field) }
        return Int(number)
    }

    func UUIDString(_ field: String) throws -> UUID {
        guard let text = record[field] as? String, let id = UUID(uuidString: text) else { throw Invalid(field) }
        return id
    }

    /// A field stored as the raw value of one of the app's enums.
    func Enum<Value: RawRepresentable>(_ field: String) throws -> Value where Value.RawValue == String {
        guard let text = record[field] as? String, let value = Value(rawValue: text) else { throw Invalid(field) }
        return value
    }

    private func Invalid(_ field: String) -> InvalidTripRecord {
        InvalidTripRecord(recordType: record.recordType, field: field)
    }
}
