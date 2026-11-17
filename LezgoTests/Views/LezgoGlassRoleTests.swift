//
//  LezgoGlassRoleTests.swift
//  LezgoTests
//

import CoreGraphics
import DeveloperToolsSupport
import Testing
@testable import Lezgo

struct LezgoGlassRoleTests {
    @Test func OnlyTheMainRoleIsTintedAndTheOthersArePlainGlass() {
        #expect(LezgoGlassRole.main.tint == ColorResource.brandYellow)
        #expect(LezgoGlassRole.second.tint == nil)
        #expect(LezgoGlassRole.destructive.tint == nil)
        #expect(LezgoGlassRole.round.tint == nil)
        #expect(LezgoGlassRole.roundOnYellow.tint == ColorResource.tripCard)
    }

    @Test func CapsuleRolesAreAtLeast56PointsHighAndRoundIs44By44() {
        #expect(LezgoGlassRole.main.minimumHeight == 56)
        #expect(LezgoGlassRole.second.minimumHeight == 56)
        #expect(LezgoGlassRole.destructive.minimumHeight == 56)
        #expect(LezgoGlassRole.round.minimumHeight == 44)
        #expect(LezgoGlassRole.round.minimumWidth == 44)
        #expect(LezgoGlassRole.main.minimumWidth == nil)
    }
}
