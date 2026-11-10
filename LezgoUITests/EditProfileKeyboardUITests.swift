//
//  EditProfileKeyboardUITests.swift
//  LezgoUITests
//
//  Created by oky faishal on 10/11/26.
//

import XCTest

/// "Save" rides up with the keyboard in Edit Profile, but never over the fields (issue #280, 1c).
final class EditProfileKeyboardUITests: XCTestCase {
    private var app = XCUIApplication()
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

    @MainActor
    func testSaveStaysBelowTheFieldsWhileTyping() throws {
        nameField.tap()
        let save = app.buttons["Save"]
        // Waits until Save has risen with the keyboard, so the frames are compared once the layout has settled.
        let risen = NSPredicate { _, _ in save.frame.maxY < self.app.frame.maxY - 200 }
        wait(for: [expectation(for: risen, evaluatedWith: nil)], timeout: 5)

        XCTAssertLessThanOrEqual(carField.frame.maxY, save.frame.minY, "Save covers Car Details")
        XCTAssertLessThanOrEqual(nameField.frame.maxY, save.frame.minY, "Save covers Name")
        XCTAssertTrue(carField.isHittable)
    }
}
