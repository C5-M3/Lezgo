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
}
