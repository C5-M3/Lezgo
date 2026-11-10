//
//  XCUIApplication+ConfirmDialog.swift
//  LezgoUITests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import XCTest

extension XCUIApplication {
    /// The app's `ConfirmDialog` with this title. The app draws its own alerts, so `alerts` cannot find them.
    func Dialog(_ title: String) -> XCUIElement {
        ConfirmDialogs().matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// Whichever `ConfirmDialog` is showing.
    var dialog: XCUIElement {
        ConfirmDialogs().firstMatch
    }

    private func ConfirmDialogs() -> XCUIElementQuery {
        descendants(matching: .any).matching(identifier: "ConfirmDialog")
    }
}
