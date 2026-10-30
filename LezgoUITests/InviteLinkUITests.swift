//
//  InviteLinkUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 30/10/26.
//

import XCTest

/// Opening an invite link fills in "Enter room code" (US-02, ADR 0020). A unit test cannot cover this: the link
/// arrives through the system and `onOpenURL`.
final class InviteLinkUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testOpeningAnInviteLinkFillsInTheRoomCode() throws {
        // The universal link only opens the app once the Netlify site is deployed, so this uses the lezgo://
        // link, which reaches the same `onOpenURL`.
        let url = try XCTUnwrap(URL(string: "lezgo://join?code=394856"))

        app.open(url)
        ConfirmOpenInLezgo()

        // The dialog card has the button trait, so its texts are not found as static texts or text fields.
        let elements = app.descendants(matching: .any)
        XCTAssertTrue(elements["Enter room code"].waitForExistence(timeout: 5))
        let codeField = elements.matching(NSPredicate(format: "placeholderValue == %@", "6 digit code")).firstMatch
        XCTAssertEqual(codeField.value as? String, "394856")
    }

    /// iOS may ask "Open in "Lezgo"?" before a link from outside the app opens it.
    private func ConfirmOpenInLezgo() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openButton = springboard.buttons["Open"]
        if openButton.waitForExistence(timeout: 3) {
            openButton.tap()
        }
    }
}
