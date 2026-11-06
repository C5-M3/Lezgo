//
//  TripRoomStartTripUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 29/10/26.
//

import XCTest

/// Starting the trip from the Trip Room (US-05). This runs as a UI test because the move to the map happens in the
/// view, when it sees the trip has started, which a view model test cannot see.
final class TripRoomStartTripUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-DebugScreen", "tripRoomLeader"]
        app.launch()
    }

    /// After the leader confirms the start, the lobby closes and the "Lez Go!" animation opens the map. The leader's
    /// "End Trip" is in the bottom card, out of reach until the card is opened.
    @MainActor
    func testStartTripOpensTheMap() throws {
        let startTrip = app.buttons["Start Trip"]
        XCTAssertTrue(startTrip.waitForExistence(timeout: 5))
        Attach(named: "Lobby before the start")

        startTrip.tap()
        let start = app.alerts.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        Attach(named: "Start trip confirmation")
        start.tap()

        let openCard = app.buttons["Show trip actions"]
        // The animation alone takes about 3 seconds; a simulator busy with a long test run can take several times that.
        XCTAssertTrue(openCard.waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["End Trip"].exists)
        // The card slides in, so it is only hittable once it has settled.
        let settled = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: openCard)
        wait(for: [settled], timeout: 5)
        openCard.tap()
        XCTAssertTrue(app.buttons["End Trip"].waitForExistence(timeout: 3))
        // The map covers the lobby, which stays in the tree below it, so its button can no longer be tapped.
        XCTAssertFalse(startTrip.isHittable)
        Attach(named: "Map after the start")
    }

    /// Cancelling the confirmation keeps everyone in the lobby.
    @MainActor
    func testCancelKeepsTheLobby() throws {
        let startTrip = app.buttons["Start Trip"]
        XCTAssertTrue(startTrip.waitForExistence(timeout: 5))

        startTrip.tap()
        let cancel = app.alerts.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.tap()

        XCTAssertFalse(app.buttons["End Trip"].waitForExistence(timeout: 2))
        XCTAssertTrue(startTrip.exists)
    }

    private func Attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
