//
//  TripRoomSetLeaderUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 29/10/26.
//

import XCTest

/// "Set as Trip Leader" in the menu of a held avatar (US-05, "Hand over the lead"). These run as UI tests because
/// the menu, the dialog and the error dialog are SwiftUI behavior that a view model test cannot see.
final class TripRoomSetLeaderUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-DebugScreen", "tripRoomLeader"]
        app.launch()
    }

    /// "Agus holds Budi, taps Set as Trip Leader and confirms": Agus becomes a member who waits for the others.
    @MainActor
    func testSetLeadHandsOverTheLeadAfterConfirming() throws {
        app.HoldAvatar(named: "Budi")
        let setLead = app.buttons["Set as Trip Leader"]
        XCTAssertTrue(setLead.waitForExistence(timeout: 3))

        setLead.tap()
        XCTAssertTrue(app.alerts["Set Budi as Trip Leader?"].waitForExistence(timeout: 3))
        Attach(named: "Set as Trip Leader dialog on Budi")
        app.alerts.buttons["Confirm"].tap()

        XCTAssertTrue(app.staticTexts["Waiting for others ..."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Start Trip"].exists)
        Attach(named: "Agus after handing over")
    }

    /// "Cancel" on the confirmation changes nothing.
    @MainActor
    func testCancelKeepsTheLeader() throws {
        app.HoldAvatar(named: "Budi")
        app.buttons["Set as Trip Leader"].tap()
        app.alerts["Set Budi as Trip Leader?"].buttons["Cancel"].tap()

        XCTAssertTrue(app.buttons["Start Trip"].waitForExistence(timeout: 2))
    }

    /// A failed handover says why, so the leader does not think it worked.
    @MainActor
    func testFailedHandOverShowsTheError() throws {
        app.terminate()
        app.launchArguments = ["-DebugScreen", "tripRoomLeaderOffline"]
        app.launch()
        app.HoldAvatar(named: "Budi")
        let setLead = app.buttons["Set as Trip Leader"]
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
}
