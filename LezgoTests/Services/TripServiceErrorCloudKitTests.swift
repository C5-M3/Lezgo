import CloudKit
import Foundation
import Testing
@testable import Lezgo

struct TripServiceErrorCloudKitTests {
    @Test(arguments: [
        (CKError.Code.networkUnavailable, TripServiceError.noNetwork),
        (.networkFailure, .noNetwork),
        (.serviceUnavailable, .noNetwork),
        (.requestRateLimited, .noNetwork),
        (.zoneBusy, .noNetwork),
        (.notAuthenticated, .notSignedInToICloud),
        (.accountTemporarilyUnavailable, .notSignedInToICloud),
        (.unknownItem, .notFound),
        (.serverRecordChanged, .conflict),
        (.permissionFailure, .notAllowed)
    ])
    func CloudKitErrorBecomesAClearTripError(code: CKError.Code, expected: TripServiceError) {
        #expect(TripServiceError(cloudKitError: CKError(code)) == expected)
    }

    @Test func PartialFailureUsesTheErrorOfTheFailedRecord() {
        let recordID = CKRecord.ID(recordName: "trip")
        let error = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: [recordID: CKError(.serverRecordChanged)]]
        )

        #expect(TripServiceError(cloudKitError: error) == .conflict)
    }

    @Test func OfflineURLErrorIsNoNetwork() {
        #expect(TripServiceError(cloudKitError: URLError(.notConnectedToInternet)) == .noNetwork)
    }

    @Test func TripServiceErrorIsKept() {
        #expect(TripServiceError(cloudKitError: TripServiceError.tripEnded) == .tripEnded)
    }

    @Test func UnreadableRecordIsNotFound() {
        let error = InvalidTripRecord(recordType: "Trip", field: "status")

        #expect(TripServiceError(cloudKitError: error) == .notFound)
    }

    @Test func UnknownErrorAsksToTryAgain() {
        struct Unexpected: Error {}

        #expect(TripServiceError(cloudKitError: Unexpected()) == .noNetwork)
    }
}
