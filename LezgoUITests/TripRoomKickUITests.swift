//
//  TripRoomKickUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 28/10/26.
//

import XCTest

/// "Kick" in Edit Profile (US-05, "Remove members"). These run as UI tests because which buttons the sheet shows,
/// and whether it stays open after "Cancel", is SwiftUI behavior that a view model test cannot see.
final class TripRoomKickUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-DebugScreen", "tripRoomLeader"]
        app.launch()
    }

    /// "Cancel" keeps Budi and the sheet; "Remove" takes Budi out and closes the sheet.
    @MainActor
    func testKickRemovesTheMemberOnlyAfterConfirming() throws {
        Avatar(named: "Budi").tap()
        let kick = app.buttons["Kick"]
        XCTAssertTrue(kick.waitForExistence(timeout: 3))
        Attach(named: "Edit Profile of Budi")

        kick.tap()
        XCTAssertTrue(app.alerts["Remove Budi from the trip?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(kick.waitForExistence(timeout: 2), "Cancel must keep Edit Profile open")

        kick.tap()
        app.alerts["Remove Budi from the trip?"].buttons["Remove"].tap()

        XCTAssertFalse(kick.waitForExistence(timeout: 2), "Remove must close Edit Profile")
        XCTAssertFalse(Avatar(named: "Budi").exists)
        Attach(named: "Participants after removing Budi")
    }

    /// The leader cannot remove or hand over to themselves, so their own profile has neither button.
    @MainActor
    func testLeaderOwnProfileHasNoGroupActions() throws {
        Avatar(named: "Agus").tap()

        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Kick"].exists)
        XCTAssertFalse(app.buttons["Set Lead"].exists)
        Attach(named: "Edit Profile of the leader")
    }

    @MainActor
    func testMemberOwnProfileHasNoGroupActions() throws {
        app.terminate()
        app.launchArguments = ["-DebugScreen", "tripRoomMember"]
        app.launch()

        Avatar(named: "Budi").tap()

        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Kick"].exists)
        XCTAssertFalse(app.buttons["Set Lead"].exists)
    }

    /// Picking another avatar and saving shows it in Participants.
    @MainActor
    func testChosenAvatarShowsInParticipants() throws {
        Avatar(named: "Budi").tap()
        let pink = app.buttons["Pink avatar"]
        XCTAssertTrue(pink.waitForExistence(timeout: 3))

        pink.tap()
        app.buttons["Save"].tap()

        let budi = Avatar(named: "Budi")
        XCTAssertTrue(budi.label.contains("Pink avatar"), "Budi's avatar is \(budi.label)")
        Attach(named: "Budi with the pink avatar")
    }

    private func Attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A participant's avatar button, whose label starts with their name. At the largest text sizes the
    /// participants sit below the overview, so this scrolls until it shows. It waits first: scrolling before the
    /// room has loaded would push the first avatars out of view on a slow simulator.
    private func Avatar(named name: String) -> XCUIElement {
        let avatar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
        _ = avatar.waitForExistence(timeout: 5)
        for _ in 0..<6 where avatar.exists && !avatar.isHittable {
            app.swipeUp()
        }
        return avatar
    }
}
