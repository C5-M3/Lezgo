//
//  SetRouteFlowUITests.swift
//  LezgoUITests
//
//  Created by Farrell Sudjatmiko on 28/10/26.
//

import XCTest

final class SetRouteFlowUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing-set-route-map"]
        app.launch()
    }

    // MARK: - SetRouteView Inline Search Flow

    @MainActor
    func testSetRouteViewPresentsSearchOnAppear() throws {
        // Given SetRouteView appears with no destinations,
        // it starts in search mode with title "Route Plan"
        let routePlanTitle = app.staticTexts["Route Plan"]
        XCTAssertTrue(routePlanTitle.waitForExistence(timeout: 5), "Expected 'Route Plan' header on appear")

        // Search text field placeholder "Where to?"
        let searchField = app.textFields["Where to?"]
        XCTAssertTrue(searchField.exists, "Expected search text field in RoutePlanCard")

        // Back button exists to cancel / go back
        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.exists, "Expected Back button")
    }

    @MainActor
    func testSetRouteViewDisplaysStartingPointAndDestinations() throws {
        // Tap Back when destinations is empty, which exits or keeps view accessible
        let routePlanTitle = app.staticTexts["Route Plan"]
        XCTAssertTrue(routePlanTitle.waitForExistence(timeout: 5))

        // Starting point row is visible in the card
        let startPointRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Current Location", "Starting Point")
        ).firstMatch
        XCTAssertTrue(startPointRow.waitForExistence(timeout: 3), "Expected Starting Point element")

        // Add destination button is hidden when destinations is empty
        let addDestinationButton = app.buttons["Add Destination"]
        XCTAssertFalse(
            addDestinationButton.exists,
            "Expected Add Destination button to be hidden when destinations is empty"
        )
    }

    @MainActor
    func testTappingStartingPointActivatesSearchForStart() throws {
        let routePlanTitle = app.staticTexts["Route Plan"]
        XCTAssertTrue(routePlanTitle.waitForExistence(timeout: 5))

        let startPointRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Current Location", "Starting Point")
        ).firstMatch
        if startPointRow.waitForExistence(timeout: 3) {
            startPointRow.tap()

            let searchStartField = app.textFields["Search starting point"]
            XCTAssertTrue(searchStartField.waitForExistence(timeout: 3), "Expected search starting point field")
        }
    }
}
