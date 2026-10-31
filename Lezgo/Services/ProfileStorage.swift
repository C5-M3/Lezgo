//
//  ProfileStorage.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation

/// The name and car this phone shows to every group (`specs/UserStories.md` → US-04, "Saved profile").
protocol ProfileStorage: Sendable {
    func SaveProfile(_ profile: ParticipantProfile)
    func LoadProfile() -> ParticipantProfile?
}

/// Keeps the profile in UserDefaults as JSON. A name and a car are not secrets, so the Keychain is not needed.
final class UserDefaultsProfileStorage: ProfileStorage, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "participant_profile") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func SaveProfile(_ profile: ParticipantProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    func LoadProfile() -> ParticipantProfile? {
        guard let data = userDefaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(ParticipantProfile.self, from: data)
    }
}
