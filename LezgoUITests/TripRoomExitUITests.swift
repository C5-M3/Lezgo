//
//  TripRoomExitUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 29/10/26.
//

import XCTest

/// Exit at the top left of the Trip Room (US-07). The view model test checks which confirmation is asked; this
/// checks that the alert shows it with the spec's words and that "Cancel" keeps the person in the room.
final class TripRoomExitUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMemberIsAskedToExitTheRoom() throws {
        Launch(debugScreen: "tripRoomMember")

        TapExit()

        let alert = app.alerts["Exit the room?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.buttons["Confirm"].exists)
        Attach(named: "Member exit alert")

        alert.buttons["Cancel"].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["Exit"].exists, "Cancel must keep the member in the room")
    }

    @MainActor
    func testLeaderIsWarnedThatTheTripEndsForEveryone() throws {
        Launch(debugScreen: "tripRoomLeader")

        TapExit()

        let alert = app.alerts["Exit and end the trip for everyone? All members will leave this trip."]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.buttons["Confirm"].exists)
        Attach(named: "Leader exit alert")
    }

    /// The leader exits on another phone, so the member is told and the room closes on OK.
    @MainActor
    func testMemberIsToldTheLeaderEndedTheTrip() throws {
        Launch(debugScreen: "tripRoomMemberLeaderEndsTrip")

        let alert = app.alerts["The leader ended the trip."]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        Attach(named: "Leader ended the trip alert")

        alert.buttons["OK"].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 1))
    }

    private func Launch(debugScreen: String) {
        app = XCUIApplication()
        app.launchArguments = ["-DebugScreen", debugScreen]
        app.launch()
    }

    private func TapExit() {
        let exit = app.buttons["Exit"]
        // The first launch on a cold simulator can take longer than the room usually needs to load.
        XCTAssertTrue(exit.waitForExistence(timeout: 10))
        exit.tap()
    }

    private func Attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
