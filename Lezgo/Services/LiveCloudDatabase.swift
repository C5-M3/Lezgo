import CloudKit
import Foundation

/// The public CloudKit database of this app's own container (ADR 0014).
///
/// `CKContainer.default()` reads the container from the entitlements, which follow each developer's bundle
/// identifier (ADR 0015), so the container is never hard-coded. Import `CloudKit/Schema.ckdb` into your container
/// before running, or every save fails.
final class LiveCloudDatabase: CloudDatabase {
    private let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    private var database: CKDatabase {
        container.publicCloudDatabase
    }

    func CurrentUserRecordName() async throws -> String {
        guard try await container.accountStatus() == .available else { throw CKError(.notAuthenticated) }
        return try await container.userRecordID().recordName
    }

    func Fetch(_ recordID: CKRecord.ID) async throws -> CKRecord {
        try await database.record(for: recordID)
    }

    func Query(
        recordType: String,
        matching conditions: [String: any CKRecordValueProtocol]
    ) async throws -> [CKRecord] {
        let predicates = conditions.map { field, value in
            NSPredicate(format: "%K == %@", argumentArray: [field, value])
        }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        var page = try await database.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)
        var records = try page.matchResults.map { try $0.1.get() }
        while let cursor = page.queryCursor {
            page = try await database.records(
                continuingMatchFrom: cursor,
                resultsLimit: CKQueryOperation.maximumResults
            )
            records += try page.matchResults.map { try $0.1.get() }
        }
        return records
    }

    func Save(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy) async throws {
        guard records.isEmpty == false else { return }
        let results = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: savePolicy,
            atomically: false
        )
        for result in results.saveResults.values {
            _ = try result.get()
        }
    }

    func Delete(_ recordIDs: [CKRecord.ID]) async throws {
        guard recordIDs.isEmpty == false else { return }
        let results = try await database.modifyRecords(saving: [], deleting: recordIDs)
        for result in results.deleteResults.values {
            do {
                try result.get()
            } catch let error as CKError where error.code == .unknownItem {
                // Already gone, for example removed by the leader a moment earlier.
                continue
            }
        }
    }
}
