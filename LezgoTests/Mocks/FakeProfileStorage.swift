//
//  FakeProfileStorage.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
@testable import Lezgo

/// Keeps the saved profile in memory, so tests never touch the phone's real one.
final class FakeProfileStorage: ProfileStorage, @unchecked Sendable {
    private(set) var savedProfile: ParticipantProfile?

    init(_ profile: ParticipantProfile? = nil) {
        savedProfile = profile
    }

    func SaveProfile(_ profile: ParticipantProfile) {
        savedProfile = profile
    }

    func LoadProfile() -> ParticipantProfile? {
        savedProfile
    }
}
