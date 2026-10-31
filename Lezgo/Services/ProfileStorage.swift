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

/// Keeps the profile in UserDefaults.
final class UserDefaultsProfileStorage: ProfileStorage, @unchecked Sendable {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func SaveProfile(_ profile: ParticipantProfile) {}

    func LoadProfile() -> ParticipantProfile? {
        nil
    }
}
