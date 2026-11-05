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

    /// After the leader taps LEZGO, the map opens over the lobby. The map's "Show whole route" is checked, not its
    /// "End Trip": that one is hidden while the map's sheet is collapsed.
    @MainActor
    func testStartTripOpensTheMap() throws {
        let startTrip = app.buttons["Start Trip"]
        XCTAssertTrue(startTrip.waitForExistence(timeout: 5))
        Attach(named: "Lobby before the start")

        startTrip.tap()
        // The LEZGO logo button; VoiceOver and this test know it as "Start". Citra is offline in the sample trip,
        // so the dialog shows the not-ready warning.
        let start = app.alerts.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts[notReadyWarning].exists)
        Attach(named: "Start trip confirmation")
        start.tap()

        XCTAssertTrue(app.buttons["Show whole route"].waitForExistence(timeout: 5))
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

        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(startTrip.isHittable)
    }

    private let notReadyWarning = "Some participants are not yet ready, are you sure you want to start the trip?"

    private func Attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
