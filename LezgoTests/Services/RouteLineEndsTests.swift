//
//  RouteLineEndsTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Testing
@testable import Lezgo

/// Apple's route starts and ends on the nearest road, so the line drawn on the map must be joined to the start and
/// destination pins, or it looks broken (hi-fi "S3 Set Route · Preview").
struct RouteLineEndsTests {
    private let start = Coordinate(latitude: -7.2900, longitude: 112.6300)
    private let roadStart = Coordinate(latitude: -7.2905, longitude: 112.6302)
    private let roadEnd = Coordinate(latitude: -7.2600, longitude: 112.7400)
    private let destination = Coordinate(latitude: -7.2598, longitude: 112.7405)

    @Test func LineReachesBothPins() {
        let line = RouteLineEnds.Joined([roadStart, roadEnd], from: start, to: destination)

        #expect(line == [start, roadStart, roadEnd, destination])
    }

    @Test func PinAlreadyOnTheLineIsNotAddedTwice() {
        let line = RouteLineEnds.Joined([start, roadEnd], from: start, to: roadEnd)

        #expect(line == [start, roadEnd])
    }

    @Test func MissingPinsLeaveTheLineAsItIs() {
        let line = RouteLineEnds.Joined([roadStart, roadEnd], from: nil, to: nil)

        #expect(line == [roadStart, roadEnd])
    }

    @Test func NoRouteDrawsNoLine() {
        // Without a route there is nothing to join: a straight line between the pins would look like a road.
        let line = RouteLineEnds.Joined([], from: start, to: destination)

        #expect(line.isEmpty)
    }
}
