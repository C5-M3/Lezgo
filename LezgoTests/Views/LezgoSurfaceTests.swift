//
//  LezgoSurfaceTests.swift
//  LezgoTests
//

import CoreGraphics
import DeveloperToolsSupport
import Testing
@testable import Lezgo

struct LezgoSurfaceTests {
    @Test func EachLevelHasItsAssetColour() {
        #expect(LezgoSurface.page.color == ColorResource.tripCard)
        #expect(LezgoSurface.level1.color == ColorResource.tripCardButton)
        #expect(LezgoSurface.level2.color == ColorResource.surfaceField)
    }

    @Test func RadiiAreThirtyTwentyAndTwelve() {
        #expect(LezgoRadius.card == 30)
        #expect(LezgoRadius.field == 20)
        #expect(LezgoRadius.small == 12)
    }
}
