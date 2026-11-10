//
//  SetRouteFocusUITests.swift
//  LezgoUITests
//
//  Created by oky faishal on 10/11/26.
//

import XCTest

/// Opening Set Route from Home puts the cursor in "Where to?", so the keyboard is already up (issue #280, 5a).
final class SetRouteFocusUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWhereToFieldHasFocusWhenSetRouteOpens() throws {
        let app = XCUIApplication()
        app.launch()

        let leadTrip = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Lead a trip")).firstMatch
        XCTAssertTrue(leadTrip.waitForExistence(timeout: 10), "Expected the Lead a trip card on Home")
        leadTrip.tap()

        let whereTo = app.textFields["Where to?"]
        XCTAssertTrue(whereTo.waitForExistence(timeout: 10), "Expected the Where to? field on Set Route")
        // Checks focus, not the on-screen keyboard: a simulator with a hardware keyboard never shows it.
        let isFocused = NSPredicate(format: "hasKeyboardFocus == true")
        let focus = expectation(for: isFocused, evaluatedWith: whereTo)
        wait(for: [focus], timeout: 5)
    }
}
