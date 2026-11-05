//
//  AvatarColorTests.swift
//  LezgoTests
//
//  Created by oky faishal on 05/11/26.
//

import Testing
@testable import Lezgo

/// The five avatar colors and the default each new car gets (`specs/UserStories.md` → US-04, "Avatar").
struct AvatarColorTests {
    @Test func ThereAreFiveColors() {
        #expect(AvatarColor.allCases == [.yellow, .blue, .green, .pink, .purple])
    }

    @Test func MemberColorsAreEveryColorButYellow() {
        #expect(AvatarColor.memberColors == [.blue, .green, .pink, .purple])
    }

    @Test func LeaderStartsYellow() {
        #expect(AvatarColor.Default(isLeader: true) == .yellow)
    }

    @Test func MemberNeverStartsYellow() {
        for _ in 0..<50 {
            #expect(AvatarColor.Default(isLeader: false) != .yellow)
        }
    }
}
