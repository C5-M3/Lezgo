//
//  TripRoomHoldMenuUITests.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 28/10/26.
//

import XCTest

/// The menu of a held avatar and Edit Profile (US-04, "Manage participants"; US-05, "Remove members"). These run as
/// UI tests because a hold, the menu and the sheet are SwiftUI behavior that a view model test cannot see.
final class TripRoomHoldMenuUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-DebugScreen", "tripRoomLeader"]
        app.launch()
    }

    /// "Cancel" keeps Budi; "Remove" takes Budi out of the trip.
    @MainActor
    func testRemoveFromTripRemovesTheMemberOnlyAfterConfirming() throws {
        app.HoldAvatar(named: "Budi")
        let remove = app.buttons["Remove from Trip"]
        XCTAssertTrue(remove.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Set as Trip Leader"].exists)
        XCTAssertTrue(app.buttons["Edit Details"].exists)
        Attach(named: "Menu of Budi held by the leader")

        remove.tap()
        XCTAssertTrue(app.alerts["Remove Budi from the trip?"].waitForExistence(timeout: 3))
        Attach(named: "Remove dialog")
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.ParticipantAvatar(named: "Budi").exists, "Cancel must keep Budi")

        app.HoldAvatar(named: "Budi")
        app.buttons["Remove from Trip"].tap()
        app.alerts["Remove Budi from the trip?"].buttons["Remove"].tap()

        let budi = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Budi,")).firstMatch
        XCTAssertFalse(budi.waitForExistence(timeout: 3))
        Attach(named: "Participants after removing Budi")
    }

    /// The leader cannot remove or hand over to themselves, so their own menu has only "Edit Details".
    @MainActor
    func testLeaderHoldingTheirOwnAvatarSeesOnlyEditDetails() throws {
        app.HoldAvatar(named: "Agus")

        XCTAssertTrue(app.buttons["Edit Details"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Remove from Trip"].exists)
        XCTAssertFalse(app.buttons["Set as Trip Leader"].exists)
    }

    @MainActor
    func testMemberHoldingTheirOwnAvatarSeesOnlyEditDetails() throws {
        app.terminate()
        app.launchArguments = ["-DebugScreen", "tripRoomMember"]
        app.launch()

        app.HoldAvatar(named: "Budi")

        XCTAssertTrue(app.buttons["Edit Details"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Remove from Trip"].exists)
        XCTAssertFalse(app.buttons["Set as Trip Leader"].exists)
        XCTAssertTrue(app.staticTexts["Hold to edit your profile"].exists)
    }

    @MainActor
    func testMemberHoldingSomeoneElseGetsNoMenu() throws {
        app.terminate()
        app.launchArguments = ["-DebugScreen", "tripRoomMember"]
        app.launch()

        app.HoldAvatar(named: "Agus")

        XCTAssertFalse(app.buttons["Edit Details"].waitForExistence(timeout: 2))
    }

    /// Tapping an avatar does nothing: only a hold opens something.
    @MainActor
    func testTappingAnAvatarDoesNothing() throws {
        app.ParticipantAvatar(named: "Budi").tap()

        XCTAssertFalse(app.buttons["Save"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Edit Details"].exists)
        XCTAssertTrue(app.staticTexts["Hold to manage participants"].exists)
    }

    /// Picking another avatar and saving shows it in Participants.
    @MainActor
    func testChosenAvatarShowsInParticipants() throws {
        app.HoldAvatar(named: "Budi")
        app.buttons["Edit Details"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 3))
        Attach(named: "Edit Profile of Budi")
        let pink = app.buttons["Pink avatar"].firstMatch
        XCTAssertTrue(pink.waitForExistence(timeout: 3))

        pink.tap()
        XCTAssertTrue(pink.waitForExistence(timeout: 2))
        app.buttons["Save"].tap()

        let budi = app.ParticipantAvatar(named: "Budi")
        XCTAssertTrue(budi.waitForExistence(timeout: 3))
        XCTAssertTrue(budi.label.contains("Pink avatar"), "Budi's avatar is \(budi.label)")
        Attach(named: "Budi with the pink avatar")
    }

    /// Scrolling the avatars chooses the one in the middle: there is no select button, and the list has no end.
    @MainActor
    func testScrollingChoosesTheAvatarInTheMiddle() throws {
        app.HoldAvatar(named: "Budi")
        app.buttons["Edit Details"].tap()
        let chosen = app.buttons.matching(NSPredicate(format: "label ENDSWITH 'avatar' AND isSelected == true"))
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 3))
        XCTAssertEqual(chosen.count, 1)
        XCTAssertEqual(chosen.firstMatch.label, "Purple avatar")

        for _ in 0..<8 {
            // The chosen avatar always stays in the middle, so it is always on screen to swipe.
            chosen.firstMatch.swipeLeft()
        }

        XCTAssertEqual(chosen.count, 1)
        XCTAssertNotEqual(chosen.firstMatch.label, "Purple avatar", "Scrolling must choose another avatar")
        Attach(named: "Edit Profile after scrolling the avatars")
    }

    private func Attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
