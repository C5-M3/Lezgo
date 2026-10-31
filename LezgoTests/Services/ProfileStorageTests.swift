//
//  ProfileStorageTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The name and car this phone shows to every group, kept on the phone (`specs/UserStories.md` → US-04).
struct ProfileStorageTests {
    /// A store of its own for each test, so tests never read each other's profile or the app's.
    private func MakeStorage() -> UserDefaultsProfileStorage {
        let suiteName = "ProfileStorageTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return UserDefaultsProfileStorage(userDefaults: defaults)
    }

    @Test func NothingIsSavedAtFirst() {
        #expect(MakeStorage().LoadProfile() == nil)
    }

    @Test func SavedProfileIsThereNextTime() {
        let storage = MakeStorage()

        storage.SaveProfile(ParticipantProfile(displayName: "Nathan", carDescription: "White Avanza"))

        #expect(storage.LoadProfile() == ParticipantProfile(displayName: "Nathan", carDescription: "White Avanza"))
    }
}
