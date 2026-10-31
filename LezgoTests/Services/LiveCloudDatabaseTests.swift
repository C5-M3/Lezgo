//
//  LiveCloudDatabaseTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import CloudKit
import Foundation
import Testing
@testable import Lezgo

/// How long a request waits when CloudKit is busy (#220). The requests themselves need iCloud.
struct LiveCloudDatabaseTests {
    private func Busy(_ code: CKError.Code, retryAfter seconds: Double?) -> CKError {
        let userInfo: [String: Any] = seconds.map { [CKErrorRetryAfterKey: $0] } ?? [:]
        return CKError(code, userInfo: userInfo)
    }

    @Test(arguments: [CKError.Code.requestRateLimited, .zoneBusy, .serviceUnavailable])
    func BusyCloudKitIsWaitedForAsLongAsItAsks(code: CKError.Code) {
        #expect(LiveCloudDatabase.RetryDelay(for: Busy(code, retryAfter: 3)) == .seconds(3))
    }

    @Test func LongWaitIsCappedAtThirtySeconds() {
        #expect(LiveCloudDatabase.RetryDelay(for: Busy(.requestRateLimited, retryAfter: 300)) == .seconds(30))
    }

    @Test func BusyWithoutAWaitIsTriedAgainAfterOneSecond() {
        #expect(LiveCloudDatabase.RetryDelay(for: Busy(.zoneBusy, retryAfter: nil)) == .seconds(1))
    }

    @Test func OtherErrorsAreNotTriedAgain() {
        #expect(LiveCloudDatabase.RetryDelay(for: CKError(.unknownItem)) == nil)
        #expect(LiveCloudDatabase.RetryDelay(for: CKError(.networkUnavailable)) == nil)
        #expect(LiveCloudDatabase.RetryDelay(for: TripServiceError.notAllowed) == nil)
    }
}
