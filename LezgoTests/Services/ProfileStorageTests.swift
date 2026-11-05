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

    @Test func SavedColorIsThereNextTime() {
        let storage = MakeStorage()
        let profile = ParticipantProfile(displayName: "Nathan", carDescription: "", avatarColor: .green)

        storage.SaveProfile(profile)

        #expect(storage.LoadProfile()?.avatarColor == .green)
    }

    @Test func ProfileSavedBeforeAvatarsStillLoads() throws {
        let suiteName = "ProfileStorageTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let oldJSON = Data(#"{"displayName":"Nathan","carDescription":"White Avanza"}"#.utf8)
        defaults.set(oldJSON, forKey: "participant_profile")

        let profile = UserDefaultsProfileStorage(userDefaults: defaults).LoadProfile()

        #expect(profile == ParticipantProfile(displayName: "Nathan", carDescription: "White Avanza"))
        #expect(profile?.avatarColor == nil)
    }
}
