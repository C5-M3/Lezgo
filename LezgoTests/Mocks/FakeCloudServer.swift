//
//  FakeCloudServer.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import CloudKit
import Foundation

/// The records of a fake CloudKit public database, shared by every `FakeCloudDatabase` (one per phone).
///
/// It remembers which version of each record it handed out, so a save with `.ifServerRecordUnchanged` fails with
/// `CKError.serverRecordChanged` when someone else saved the record in between, like CloudKit does.
final class FakeCloudServer {
    /// When set, every call fails with this error, for example `CKError(.networkUnavailable)`.
    var failure: (any Error)?
    private(set) var records: [CKRecord.ID: CKRecord] = [:]
    private(set) var saveCount = 0
    private(set) var handOutCount = 0
    private(set) var queryCount = 0
    /// The time the server gives to the records it saves. Tests move it with `AdvanceClock(by:)`.
    private(set) var now = Date(timeIntervalSince1970: 1_800_000_000)
    private var modifiedAt: [CKRecord.ID: Date] = [:]
    private var versions: [CKRecord.ID: Int] = [:]
    private var handedOut: [ObjectIdentifier: (record: CKRecord, version: Int)] = [:]

    func ThrowFailure() throws {
        if let failure { throw failure }
    }

    func AdvanceClock(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

    /// A copy of the stored record with its modification time, remembered with its current version.
    func HandOut(_ recordID: CKRecord.ID) -> CKRecord? {
        guard let stored = records[recordID] else { return nil }
        let copy = StampedRecord.Make(copying: stored, modifiedAt: modifiedAt[recordID])
        handedOut[ObjectIdentifier(copy)] = (copy, versions[recordID, default: 0])
        handOutCount += 1
        return copy
    }

    func Save(_ record: CKRecord, savePolicy: CKModifyRecordsOperation.RecordSavePolicy) throws {
        let recordID = record.recordID
        if savePolicy == .ifServerRecordUnchanged, let stored = records[recordID] {
            let handedOutVersion = handedOut[ObjectIdentifier(record)]?.version
            guard handedOutVersion == versions[recordID, default: 0] else {
                throw CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: stored])
            }
        }
        let target = records[recordID] ?? CKRecord(recordType: record.recordType, recordID: recordID)
        for key in Set(record.allKeys() + record.changedKeys()) {
            target[key] = record[key]
        }
        records[recordID] = target
        modifiedAt[recordID] = now
        versions[recordID, default: 0] += 1
        saveCount += 1
    }

    func CountQuery() {
        queryCount += 1
    }

    /// What queries see. CloudKit's query index lags behind saves and deletes, so after `FreezeQueryIndex()` a
    /// query sees the records as they were then (deleted ones included), until `CatchUpQueryIndex()`.
    private var queryIndex: [CKRecord.ID: (record: CKRecord, modifiedAt: Date?)]?

    func FreezeQueryIndex() {
        queryIndex = records.reduce(into: [:]) { index, entry in
            guard let copy = entry.value.copy() as? CKRecord else { return }
            index[entry.key] = (copy, modifiedAt[entry.key])
        }
    }

    func CatchUpQueryIndex() {
        queryIndex = nil
    }

    /// Copies of the records a query can see now that pass `isIncluded`.
    func QueryableRecords(where isIncluded: (CKRecord) -> Bool) -> [CKRecord] {
        guard let queryIndex else { return records.values.filter(isIncluded).compactMap { HandOut($0.recordID) } }
        return queryIndex.values
            .filter { isIncluded($0.record) }
            .map { StampedRecord.Make(copying: $0.record, modifiedAt: $0.modifiedAt) }
    }

    func Delete(_ recordID: CKRecord.ID) {
        records[recordID] = nil
        modifiedAt[recordID] = nil
    }
}

/// A record as CloudKit hands it out: it knows when the server last saved it. `CKRecord.modificationDate` is
/// read-only, so a test record gets one by overriding it.
private final class StampedRecord: CKRecord, @unchecked Sendable {
    private var stamp: Date?

    override var modificationDate: Date? { stamp }

    static func Make(copying record: CKRecord, modifiedAt: Date?) -> CKRecord {
        let stamped = StampedRecord(recordType: record.recordType, recordID: record.recordID)
        for key in record.allKeys() {
            stamped[key] = record[key]
        }
        stamped.stamp = modifiedAt
        return stamped
    }
}
