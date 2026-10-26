#if DEBUG
import CloudKit
import Foundation
import Testing
@testable import Lezgo

struct MeasuringCloudDatabaseTests {
    let server = FakeCloudServer()
    let recorder = LoadCheckRecorder()

    private var database: MeasuringCloudDatabase {
        MeasuringCloudDatabase(FakeCloudDatabase(server: server, userRecordName: "_load"), recorder: recorder)
    }

    @Test func EveryRequestIsRecordedWithItsOperation() async throws {
        let record = TripRecordMapper.MakeRecord(TripFixtures.Trip())

        try await database.Save([record], savePolicy: .allKeys)
        _ = try await database.Fetch(record.recordID)
        _ = try await database.Query(recordType: "Trip", matching: ["roomCode": "897654"])
        try await database.Delete([record.recordID])

        #expect(recorder.samples.map(\.operation) == ["save", "fetch", "query", "delete"])
        #expect(recorder.samples.allSatisfy { $0.errorCode == nil })
    }

    @Test func FailedRequestIsRecordedWithItsCodeAndStillThrows() async {
        server.failure = CKError(.requestRateLimited)

        await #expect(throws: CKError.self) {
            _ = try await database.Fetch(CKRecord.ID(recordName: "missing"))
        }
        #expect(recorder.samples.map(\.errorCode) == ["requestRateLimited"])
    }

    @Test(arguments: [
        (CKError.Code.requestRateLimited, "requestRateLimited"),
        (.zoneBusy, "zoneBusy"),
        (.networkFailure, "networkFailure"),
        (.networkUnavailable, "networkUnavailable"),
        (.serviceUnavailable, "serviceUnavailable"),
        (.serverRecordChanged, "serverRecordChanged"),
        (.unknownItem, "unknownItem"),
        (.operationCancelled, "operationCancelled")
    ])
    func ErrorNamesMatchCloudKit(code: CKError.Code, name: String) {
        #expect(MeasuringCloudDatabase.ErrorName(CKError(code)) == name)
    }

    @Test func OtherErrorsKeepTheirNumber() {
        #expect(MeasuringCloudDatabase.ErrorName(CKError(.quotaExceeded)) == "CKError 25")
        #expect(MeasuringCloudDatabase.ErrorName(URLError(.timedOut)) == "other")
    }

    @Test func RequestCancelledBecauseTheCheckStoppedIsNotAnError() async {
        server.failure = CKError(.operationCancelled)
        let database = database
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try? await database.Fetch(CKRecord.ID(recordName: "any"))
        }
        await task.value

        #expect(recorder.samples.isEmpty)
    }

    @Test func CancelledRequestWhileRunningIsStillCounted() async {
        server.failure = CKError(.operationCancelled)

        _ = try? await database.Fetch(CKRecord.ID(recordName: "any"))

        #expect(recorder.samples.map(\.errorCode) == ["operationCancelled"])
    }
}
#endif
