//
//  XCUIApplication+TripRoom.swift
//  LezgoUITests
//
//  Created by Oky Faishal on 06/11/26.
//

import XCTest

extension XCUIApplication {
    /// A participant's avatar in the Trip Room, whose label starts with their name. At the largest text sizes the
    /// participants sit below the overview, so this scrolls until it shows. It waits first: scrolling before the
    /// room has loaded would push the first avatars out of view on a slow simulator.
    func ParticipantAvatar(named name: String) -> XCUIElement {
        let avatar = descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
        _ = avatar.waitForExistence(timeout: 5)
        for _ in 0..<6 where avatar.exists && !avatar.isHittable {
            swipeUp()
        }
        return avatar
    }

    /// Holds a participant's avatar until its menu opens (US-04, "Manage participants").
    func HoldAvatar(named name: String) {
        ParticipantAvatar(named: name).press(forDuration: 1.2)
    }
}
