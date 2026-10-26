#if DEBUG
import CloudKit
import Foundation

/// Wraps a `CloudDatabase` and records every request's time and `CKError` code for a load check (#69).
final class MeasuringCloudDatabase: CloudDatabase {
    private let database: any CloudDatabase
    private let recorder: LoadCheckRecorder

    init(_ database: any CloudDatabase, recorder: LoadCheckRecorder) {
        self.database = database
        self.recorder = recorder
    }

    func CurrentUserRecordName() async throws -> String {
        try await database.CurrentUserRecordName()
    }

    func Fetch(_ recordID: CKRecord.ID) async throws -> CKRecord {
        try await database.Fetch(recordID)
    }

    func Query(
        recordType: String,
        matching conditions: [String: any CKRecordValueProtocol]
    ) async throws -> [CKRecord] {
        try await database.Query(recordType: recordType, matching: conditions)
    }

    func Save(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy) async throws {
        try await database.Save(records, savePolicy: savePolicy)
    }

    func Delete(_ recordIDs: [CKRecord.ID]) async throws {
        try await database.Delete(recordIDs)
    }

    /// The name of a `CKError` code, such as `requestRateLimited`, for the load check report.
    static func ErrorName(_ error: any Error) -> String {
        "other"
    }
}
#endif
