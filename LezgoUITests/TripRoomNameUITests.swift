//
//  TripRoomNameUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 06/11/26.
//

import XCTest

/// Unique names in Edit Profile (US-04): the check when the field is left, and the check on "Save". These run as UI
/// tests because the red field, the disabled "Save" and the dialog are SwiftUI behavior.
final class TripRoomNameUITests: XCTestCase {
    private var app = XCUIApplication()
    private let taken = "Name already used in this trip"
    /// The two fields of Edit Profile, in the order they are shown.
    private var nameField: XCUIElement { app.textFields.element(boundBy: 0) }
    private var carField: XCUIElement { app.textFields.element(boundBy: 1) }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-DebugScreen", "tripRoomMember"]
        app.launch()
        app.HoldAvatar(named: "Budi")
        app.buttons["Edit Details"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 3))
    }

    /// Leaving the field marks a name another car has; tapping the field again clears it.
    @MainActor
    func testLeavingTheFieldFlagsATakenName() throws {
        ReplaceName(with: "agus ")
        carField.tap()

        XCTAssertTrue(app.staticTexts[taken].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        Attach(named: "Name already used")

        nameField.tap()
        XCTAssertFalse(app.staticTexts[taken].exists)
    }

    /// Saving straight away, before the field was left, still refuses the name and says why.
    @MainActor
    func testSavingATakenNameRightAwayShowsTheDialog() throws {
        ReplaceName(with: "Citra")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.alerts[taken].waitForExistence(timeout: 3))
        Attach(named: "Dialog for a taken name")
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.staticTexts[taken].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
    }

    /// Keeping my own name, only in other letters, is not a clash.
    @MainActor
    func testKeepingMyOwnNameIsAllowed() throws {
        ReplaceName(with: "budi")
        carField.tap()

        XCTAssertFalse(app.staticTexts[taken].exists)
        XCTAssertTrue(app.buttons["Save"].isEnabled)
    }

    /// Selects the whole name by a double tap on its first word (the sample names are one word) and types over it.
    private func ReplaceName(with name: String) {
        nameField.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).doubleTap()
        nameField.typeText(name)
    }

    private func Attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
