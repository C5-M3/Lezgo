//
//  ActiveTripStorageTests.swift
//  LezgoTests
//
//  Created by Rizal Pratama on 27/10/26.
//

import Foundation
import Testing
@testable import Lezgo

@Suite("ActiveTripStorage Tests")
struct ActiveTripStorageTests {

    private func makeTemporaryStorage() -> (UserDefaultsActiveTripStorage, UserDefaults, String) {
        let suiteName = "test.suite.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        let key = "test_active_trip"
        let storage = UserDefaultsActiveTripStorage(userDefaults: userDefaults, storageKey: key)
        return (storage, userDefaults, suiteName)
    }

    @Test("Saving and loading active trip summary round-trips successfully")
    func saveAndLoadActiveTrip() {
        let (storage, userDefaults, suiteName) = makeTemporaryStorage()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let original = ActiveTripSummary(
            tripID: UUID(),
            myParticipantID: UUID(),
            roomCode: "654321",
            startName: "Universitas Ciputra",
            destinationName: "Ciputra World",
            distanceText: "9 km",
            memberNames: ["Nathan", "Mathew"],
            status: .lobby,
            isLeader: true
        )

        storage.SaveActiveTrip(original)
        let loaded = storage.LoadActiveTrip()

        #expect(loaded != nil)
        #expect(loaded?.tripID == original.tripID)
        #expect(loaded?.myParticipantID == original.myParticipantID)
        #expect(loaded?.roomCode == "654321")
        #expect(loaded?.startName == "Universitas Ciputra")
        #expect(loaded?.destinationName == "Ciputra World")
        #expect(loaded?.distanceText == "9 km")
        #expect(loaded?.memberNames == ["Nathan", "Mathew"])
        #expect(loaded?.status == .lobby)
        #expect(loaded?.isLeader == true)
    }

    @Test("Clearing active trip removes stored data")
    func clearActiveTrip() {
        let (storage, userDefaults, suiteName) = makeTemporaryStorage()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let summary = ActiveTripSummary(
            tripID: UUID(),
            myParticipantID: UUID(),
            roomCode: "123456",
            startName: "Point A",
            destinationName: "Point B",
            memberNames: ["Driver"],
            status: .lobby,
            isLeader: false
        )

        storage.SaveActiveTrip(summary)
        #expect(storage.LoadActiveTrip() != nil)

        storage.ClearActiveTrip()
        #expect(storage.LoadActiveTrip() == nil)
    }
}
