//
//  TripRoomSetLeaderUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 29/10/26.
//

import XCTest

/// Handing over the lead in the Trip Room (US-05). These run as UI tests because swipe actions and the picker
/// sheet are SwiftUI behavior that a view model test cannot see.
final class TripRoomSetLeaderUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-DebugScreen", "tripRoomLeader"]
        app.launch()
    }

    /// "Agus swipes Budi right, taps Set Lead and confirms": Agus becomes a member who waits for the others.
    @MainActor
    func testSetLeadSwipeHandsOverTheLeadAfterConfirming() throws {
        let budi = Row(named: "Budi")
        XCTAssertTrue(budi.waitForExistence(timeout: 5))

        budi.swipeRight()
        let setLead = app.buttons["Set Lead"]
        XCTAssertTrue(setLead.waitForExistence(timeout: 3))
        setLead.tap()

        XCTAssertTrue(app.alerts["Set Budi as Trip Leader?"].waitForExistence(timeout: 3))
        Attach(named: "Set Lead alert on Budi")
        app.alerts.buttons["Confirm"].tap()

        XCTAssertTrue(app.staticTexts["Waiting for others ..."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Room options"].exists)
        Attach(named: "Agus after handing over")
    }

    /// On the leader's own row "Set Lead" shows but does nothing.
    @MainActor
    func testSetLeadOnTheLeaderRowDoesNothing() throws {
        let agus = Row(named: "Agus")
        XCTAssertTrue(agus.waitForExistence(timeout: 5))

        agus.swipeRight()
        let setLead = app.buttons["Set Lead"]
        XCTAssertTrue(setLead.waitForExistence(timeout: 3))
        Attach(named: "Set Lead on the leader row")

        setLead.tap()

        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Room options"].exists)
    }

    /// "Cancel" on the picker changes nothing.
    @MainActor
    func testCancelOnThePickerKeepsTheLeader() throws {
        let options = app.buttons["Room options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        app.buttons["Set leader"].tap()
        XCTAssertTrue(app.navigationBars["Pick Your New Leader"].waitForExistence(timeout: 3))

        app.navigationBars["Pick Your New Leader"].buttons["Cancel"].tap()

        XCTAssertFalse(app.navigationBars["Pick Your New Leader"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Room options"].exists)
    }

    /// A failed handover from the picker must still show the error. The sheet closes on "Confirm", and an alert
    /// presented while it is still closing is dropped, so the leader would think the handover worked.
    @MainActor
    func testFailedHandOverFromThePickerShowsTheError() throws {
        app.terminate()
        app.launchArguments = ["-DebugScreen", "tripRoomLeaderOffline"]
        app.launch()
        let options = app.buttons["Room options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        app.buttons["Set leader"].tap()
        let budi = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Budi,")).firstMatch
        XCTAssertTrue(budi.waitForExistence(timeout: 3))

        budi.tap()
        XCTAssertTrue(app.alerts["Set Budi as Trip Leader?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Confirm"].tap()

        XCTAssertTrue(app.alerts["Error"].waitForExistence(timeout: 5))
        Attach(named: "Error after a failed handover from the picker")
        let message = "No internet connection. Check your connection and try again."
        XCTAssertTrue(app.alerts["Error"].staticTexts[message].exists)
    }

    private func Attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// At the largest text sizes the participants sit below the route, and the list only builds rows on screen, so
    /// this scrolls down until the row shows.
    private func Row(named name: String) -> XCUIElement {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
        _ = row.waitForExistence(timeout: 5)
        for _ in 0..<6 where !row.isHittable {
            app.swipeUp()
        }
        return row
    }
}
