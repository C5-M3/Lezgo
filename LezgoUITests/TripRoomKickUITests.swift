//
//  TripRoomKickUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 28/10/26.
//

import XCTest

/// Swiping a row to "Kick" in the Trip Room (US-05). These run as UI tests because the bugs live in how SwiftUI
/// treats swipe action buttons, which a view model test cannot see.
final class TripRoomKickUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-DebugScreen", "tripRoomLeader"]
        app.launch()
    }

    /// The row must stay until the leader confirms "Remove": a destructive swipe button deletes it straight away.
    @MainActor
    func testKickKeepsTheMemberUntilRemovalIsConfirmed() throws {
        let budi = Row(named: "Budi")
        XCTAssertTrue(budi.waitForExistence(timeout: 5))

        budi.swipeLeft()
        app.buttons["Kick"].tap()

        XCTAssertTrue(app.alerts["Remove Budi from the trip?"].waitForExistence(timeout: 3))
        Attach(named: "Kick alert on Budi")

        app.alerts.buttons["Cancel"].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 1))
        Attach(named: "After Cancel")
        // A destructive swipe button makes SwiftUI drop a row from the list on tap, and not always the swiped one.
        for name in ["Agus", "Budi", "Citra"] {
            XCTAssertTrue(Row(named: name).exists, "\(name) must stay in Participants when the removal is cancelled")
        }
    }

    /// On the leader's own row "Kick" shows but does nothing.
    @MainActor
    func testKickOnTheLeaderRowDoesNothing() throws {
        let agus = Row(named: "Agus")
        XCTAssertTrue(agus.waitForExistence(timeout: 5))

        agus.swipeLeft()
        let kick = app.buttons["Kick"]
        XCTAssertTrue(kick.waitForExistence(timeout: 3))
        Attach(named: "Kick on the leader row")

        kick.tap()

        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(agus.exists)
    }

    private func Attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// At the largest text sizes the participants sit below the route, and the list only builds rows on screen, so
    /// this scrolls down until the row shows. It waits for the row first: scrolling before the list has loaded
    /// would push the first rows out of view on a slow simulator.
    private func Row(named name: String) -> XCUIElement {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
        _ = row.waitForExistence(timeout: 5)
        for _ in 0..<6 where !row.isHittable {
            app.swipeUp()
        }
        return row
    }
}
