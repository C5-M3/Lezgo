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

    // MARK: - SetRouteMapView & LocationSearchSheet

    @MainActor
    func testSetRouteMapViewPresentsLocationSearchSheetOnAppear() throws {
        // Given SetRouteMapView appears with no destinations,
        // it presents LocationSearchSheet with title "Destination"
        let navBar = app.navigationBars["Destination"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Expected LocationSearchSheet for Destination on appear")

        // Search field prompt "Where to?"
        let searchField = app.searchFields["Where to?"]
        XCTAssertTrue(searchField.exists, "Expected searchable field in LocationSearchSheet")

        // Cancel button exists to dismiss the sheet
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Expected Cancel button on LocationSearchSheet")
    }

    @MainActor
    func testLocationSearchSheetCancelDismissesToSetRouteSheet() throws {
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // SetRouteSheet should now be visible with navigation title "Set Route"
        let setRouteNavBar = app.navigationBars["Set Route"]
        XCTAssertTrue(setRouteNavBar.waitForExistence(timeout: 3), "Expected Set Route sheet after dismissing search")
    }

    // MARK: - SetRouteSheet

    @MainActor
    func testSetRouteSheetDisplaysStartingPointAndDestinationsSections() throws {
        // Dismiss the initial auto-presented search sheet
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // Verify Starting Point section element
        let startPointButton = app.buttons["Choose Starting Point..."]
        XCTAssertTrue(startPointButton.waitForExistence(timeout: 3), "Expected Choose Starting Point button")

        // Verify "Add..." button in Destinations section
        let addDestinationButton = app.buttons["Add..."]
        XCTAssertTrue(addDestinationButton.exists, "Expected Add button in Destinations section")
    }

    @MainActor
    func testTappingStartingPointOpensSearchSheetForStart() throws {
        // Dismiss initial destination search sheet
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // Tap Starting Point
        let startPointButton = app.buttons["Choose Starting Point..."]
        XCTAssertTrue(startPointButton.waitForExistence(timeout: 3))
        startPointButton.tap()

        // Should present LocationSearchSheet with title "Starting Point"
        let startNavBar = app.navigationBars["Starting Point"]
        XCTAssertTrue(startNavBar.waitForExistence(timeout: 3), "Expected Starting Point search sheet")

        // Search field prompt "Change start location"
        let searchField = app.searchFields["Change start location"]
        XCTAssertTrue(searchField.exists, "Expected 'Change start location' search field")
    }

    @MainActor
    func testTappingAddDestinationOpensSearchSheet() throws {
        // Dismiss initial destination search sheet
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // Tap "Add..." in Destinations
        let addButton = app.buttons["Add..."]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        // Should present LocationSearchSheet for Destination
        let destinationNavBar = app.navigationBars["Destination"]
        XCTAssertTrue(destinationNavBar.waitForExistence(timeout: 3), "Expected Destination search sheet")
    }
}
