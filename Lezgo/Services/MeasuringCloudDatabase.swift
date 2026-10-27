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
        try await Measure("user") { try await database.CurrentUserRecordName() }
    }

    func Fetch(_ recordID: CKRecord.ID) async throws -> CKRecord {
        try await Measure("fetch") { try await database.Fetch(recordID) }
    }

    func Fetch(_ recordIDs: [CKRecord.ID]) async throws -> [CKRecord] {
        try await Measure("fetchMany") { try await database.Fetch(recordIDs) }
    }

    func Query(
        recordType: String,
        matching conditions: [String: any CKRecordValueProtocol]
    ) async throws -> [CKRecord] {
        try await Measure("query") { try await database.Query(recordType: recordType, matching: conditions) }
    }

    func Save(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy) async throws {
        try await Measure("save") { try await database.Save(records, savePolicy: savePolicy) }
    }

    func Delete(_ recordIDs: [CKRecord.ID]) async throws {
        try await Measure("delete") { try await database.Delete(recordIDs) }
    }

    /// The name of a `CKError` code, such as `requestRateLimited`, for the load check report.
    static func ErrorName(_ error: any Error) -> String {
        guard let error = error as? CKError else { return "other" }
        switch error.code {
        case .requestRateLimited: return "requestRateLimited"
        case .zoneBusy: return "zoneBusy"
        case .networkFailure: return "networkFailure"
        case .networkUnavailable: return "networkUnavailable"
        case .serviceUnavailable: return "serviceUnavailable"
        case .serverRecordChanged: return "serverRecordChanged"
        case .unknownItem: return "unknownItem"
        case .operationCancelled: return "operationCancelled"
        default: return "CKError \(error.code.rawValue)"
        }
    }

    /// Runs one request and records how long it took and how it failed, then passes its result or error on.
    private func Measure<Result>(_ operation: String, _ request: () async throws -> Result) async throws -> Result {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let result = try await request()
            recorder.Record(LoadCheckSample(operation: operation, duration: start.duration(to: clock.now)))
            return result
        } catch {
            // Requests cut off because the check was stopped are not CloudKit failures.
            if Task.isCancelled, error is CancellationError || (error as? CKError)?.code == .operationCancelled {
                throw error
            }
            let sample = LoadCheckSample(
                operation: operation,
                duration: start.duration(to: clock.now),
                errorCode: Self.ErrorName(error)
            )
            recorder.Record(sample)
            throw error
        }
    }
}
#endif
