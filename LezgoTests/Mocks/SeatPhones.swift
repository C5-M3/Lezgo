//
//  SeatPhones.swift
//  LezgoTests
//
//  Created by Oky Faishal on 16/11/26.
//

import CloudKit
import Foundation
@testable import Lezgo

/// Two phones signed in to the same iCloud account (`first` and `second`) and one phone of another account
/// (`other`), using either `TripService` implementation (ADR 0031).
struct SeatPhones {
    static let accountName = "_agus0001"

    let first: any TripService
    let second: any TripService
    let other: any TripService
    /// The fake CloudKit database; `nil` for the in-memory service.
    let server: FakeCloudServer?

    init(_ kind: TripPhones.Kind) {
        switch kind {
        case .inMemory:
            let store = InMemoryTripStore()
            func Phone(_ name: String) -> any TripService {
                InMemoryTripService(store: store, userRecordID: name, clock: { TripFixtures.now })
            }
            first = Phone(Self.accountName)
            second = Phone(Self.accountName)
            other = Phone("_budi7F3A")
            server = nil
        case .live:
            let fakeServer = FakeCloudServer()
            func Phone(_ name: String) -> any TripService {
                LiveTripService(
                    database: FakeCloudDatabase(server: fakeServer, userRecordName: name),
                    clock: { TripFixtures.now },
                    pollInterval: .milliseconds(5)
                )
            }
            first = Phone(Self.accountName)
            second = Phone(Self.accountName)
            other = Phone("_budi7F3A")
            server = fakeServer
        }
    }

    /// The seat record of the shared account, in the fake CloudKit database.
    static var seatRecordID: CKRecord.ID {
        CKRecord.ID(recordName: TripSeat.RecordName(forAccount: accountName))
    }
}

/// `true` when `work` finishes within `duration`; the work is cancelled otherwise.
@MainActor
func Finishes(within duration: Duration = .seconds(3), _ work: @escaping () async -> Void) async -> Bool {
    var isDone = false
    let task = Task {
        await work()
        isDone = true
    }
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: duration)
    while isDone == false, clock.now < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
    task.cancel()
    return isDone
}
