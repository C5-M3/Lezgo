//
//  AvatarTests.swift
//  LezgoTests
//
//  Created by oky faishal on 05/11/26.
//

import Testing
@testable import Lezgo

/// The five avatars and the default each new car gets (`specs/UserStories.md` → US-04, "Avatar").
struct AvatarTests {
    @Test func ThereAreFiveAvatars() {
        #expect(Avatar.allCases == [.yellow, .blue, .green, .pink, .purple])
    }

    @Test func KeyIsTheEndOfTheAssetNames() {
        // The mascot images are named "MainSelectedBlue", "OntripGlowBlue", …; the key is what they share.
        #expect(Avatar.allCases.map(\.rawValue) == ["Yellow", "Blue", "Green", "Pink", "Purple"])
    }

    @Test func MemberAvatarsAreEveryAvatarButYellow() {
        #expect(Avatar.memberAvatars == [.blue, .green, .pink, .purple])
    }

    @Test func LeaderStartsYellow() {
        #expect(Avatar.Default(isLeader: true) == .yellow)
    }

    @Test func MemberNeverStartsYellow() {
        for _ in 0..<50 {
            #expect(Avatar.Default(isLeader: false) != .yellow)
        }
    }
}
