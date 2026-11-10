//
//  TripMapHeadingTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 10/11/26.
//

import Testing
@testable import Lezgo

/// The compass shows only while the map is turned away from north, and a tap asks the map to face north.
struct TripMapHeadingTests {
    @Test(arguments: [0.0, 1.5, -1.5, 359.0, 360.0, 720.5])
    func CompassHidesWhileTheMapFacesNorth(degrees: Double) {
        let heading = TripMapHeading()

        heading.Update(degrees)

        #expect(heading.isTurned == false)
    }

    @Test(arguments: [3.0, 45.0, 180.0, 300.0, -90.0])
    func CompassShowsWhileTheMapIsTurned(degrees: Double) {
        let heading = TripMapHeading()

        heading.Update(degrees)

        #expect(heading.isTurned)
    }

    @Test func EachTapAsksTheMapToFaceNorthAgain() {
        let heading = TripMapHeading()

        heading.PointNorth()
        heading.PointNorth()

        #expect(heading.northRequest == 2)
    }
}
