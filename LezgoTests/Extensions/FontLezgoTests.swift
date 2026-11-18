//
//  FontLezgoTests.swift
//  LezgoTests
//

import SwiftUI
import Testing
@testable import Lezgo

struct FontLezgoTests {
    @Test func PageTitleKeepsTheTripHistorySize() {
        #expect(Font.lezgoPageTitle == Font.title2.weight(.bold))
    }

    @Test func SectionTitleIsBiggerThanTheHeadlineValuesUnderIt() {
        #expect(Font.lezgoSectionTitle == Font.title2.weight(.semibold))
        #expect(Font.lezgoSectionTitle != Font.headline)
    }
}
