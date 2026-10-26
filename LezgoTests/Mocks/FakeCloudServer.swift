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
    private var versions: [CKRecord.ID: Int] = [:]
    private var handedOut: [ObjectIdentifier: (record: CKRecord, version: Int)] = [:]

    func ThrowFailure() throws {
        if let failure { throw failure }
    }

    /// A copy of the stored record, remembered with its current version.
    func HandOut(_ recordID: CKRecord.ID) -> CKRecord? {
        guard let stored = records[recordID], let copy = stored.copy() as? CKRecord else { return nil }
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
        versions[recordID, default: 0] += 1
        saveCount += 1
    }

    func Delete(_ recordID: CKRecord.ID) {
        records[recordID] = nil
    }
}
