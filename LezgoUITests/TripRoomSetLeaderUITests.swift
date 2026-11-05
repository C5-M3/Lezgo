//
//  TripRoomSetLeaderUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 29/10/26.
//

import XCTest

/// "Set Lead" in Edit Profile (US-05, "Hand over the lead"). These run as UI tests because the sheet closing and an
/// error alert inside it are SwiftUI behavior that a view model test cannot see.
final class TripRoomSetLeaderUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-DebugScreen", "tripRoomLeader"]
        app.launch()
    }

    /// "Agus taps Budi, taps Set Lead and confirms": Agus becomes a member who waits for the others.
    @MainActor
    func testSetLeadHandsOverTheLeadAfterConfirming() throws {
        Avatar(named: "Budi").tap()
        let setLead = app.buttons["Set Lead"]
        XCTAssertTrue(setLead.waitForExistence(timeout: 3))

        setLead.tap()
        XCTAssertTrue(app.alerts["Set Budi as Trip Leader?"].waitForExistence(timeout: 3))
        Attach(named: "Set Lead alert on Budi")
        app.alerts.buttons["Confirm"].tap()

        XCTAssertTrue(app.staticTexts["Waiting for others ..."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Start Trip"].exists)
        Attach(named: "Agus after handing over")
    }

    /// "Cancel" on the confirmation changes nothing and keeps Edit Profile open.
    @MainActor
    func testCancelKeepsTheLeader() throws {
        Avatar(named: "Budi").tap()
        let setLead = app.buttons["Set Lead"]
        XCTAssertTrue(setLead.waitForExistence(timeout: 3))

        setLead.tap()
        app.alerts["Set Budi as Trip Leader?"].buttons["Cancel"].tap()

        XCTAssertTrue(setLead.waitForExistence(timeout: 2))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Start Trip"].waitForExistence(timeout: 2))
    }

    /// A failed handover keeps Edit Profile open and says why, so the leader does not think it worked.
    @MainActor
    func testFailedHandOverShowsTheError() throws {
        app.terminate()
        app.launchArguments = ["-DebugScreen", "tripRoomLeaderOffline"]
        app.launch()
        Avatar(named: "Budi").tap()
        let setLead = app.buttons["Set Lead"]
        XCTAssertTrue(setLead.waitForExistence(timeout: 3))

        setLead.tap()
        app.alerts["Set Budi as Trip Leader?"].buttons["Confirm"].tap()

        XCTAssertTrue(app.alerts["Error"].waitForExistence(timeout: 5))
        Attach(named: "Error after a failed handover")
        let message = "No internet connection. Check your connection and try again."
        XCTAssertTrue(app.alerts["Error"].staticTexts[message].exists)
    }

    private func Attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A participant's avatar button, whose label starts with their name; scrolls until it shows at large text sizes.
    private func Avatar(named name: String) -> XCUIElement {
        let avatar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
        _ = avatar.waitForExistence(timeout: 5)
        for _ in 0..<6 where avatar.exists && !avatar.isHittable {
            app.swipeUp()
        }
        return avatar
    }
}
