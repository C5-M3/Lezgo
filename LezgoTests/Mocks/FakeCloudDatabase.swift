import CloudKit
import Foundation
@testable import Lezgo

/// One phone's view of a `FakeCloudServer`: the same records for everyone, with this phone's iCloud user.
final class FakeCloudDatabase: CloudDatabase {
    let server: FakeCloudServer
    /// `nil` acts like a phone that is not signed in to iCloud.
    let userRecordName: String?

    init(server: FakeCloudServer, userRecordName: String?) {
        self.server = server
        self.userRecordName = userRecordName
    }

    func CurrentUserRecordName() async throws -> String {
        try server.ThrowFailure()
        guard let userRecordName else { throw CKError(.notAuthenticated) }
        return userRecordName
    }

    func Fetch(_ recordID: CKRecord.ID) async throws -> CKRecord {
        try server.ThrowFailure()
        guard let record = server.HandOut(recordID) else { throw CKError(.unknownItem) }
        return record
    }

    func Fetch(_ recordIDs: [CKRecord.ID]) async throws -> [CKRecord] {
        try server.ThrowFailure()
        return recordIDs.compactMap { server.HandOut($0) }
    }

    func Query(
        recordType: String,
        matching conditions: [String: any CKRecordValueProtocol]
    ) async throws -> [CKRecord] {
        try server.ThrowFailure()
        server.CountQuery()
        return server.records.values
            .filter { $0.recordType == recordType && Matches($0, conditions) }
            .compactMap { server.HandOut($0.recordID) }
    }

    func Save(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy) async throws {
        try server.ThrowFailure()
        for record in records {
            try server.Save(record, savePolicy: savePolicy)
        }
    }

    func Delete(_ recordIDs: [CKRecord.ID]) async throws {
        try server.ThrowFailure()
        recordIDs.forEach(server.Delete)
    }

    private func Matches(_ record: CKRecord, _ conditions: [String: any CKRecordValueProtocol]) -> Bool {
        conditions.allSatisfy { field, expected in
            if let expected = expected as? CKRecord.Reference {
                return (record[field] as? CKRecord.Reference)?.recordID == expected.recordID
            }
            return (record[field] as AnyObject).isEqual(expected as AnyObject)
        }
    }
}
