//
//  RoutePositionTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// A route near the equator, where 0.01° is about 1,113 m in both directions: 1,113 m east, then 1,113 m north.
struct RoutePositionTests {
    private static let metresPerHundredthDegree = 1_113.2
    private let route = [
        Coordinate(latitude: 0, longitude: 0),
        Coordinate(latitude: 0, longitude: 0.01),
        Coordinate(latitude: 0.01, longitude: 0.01)
    ]

    private func Locate(latitude: Double, longitude: Double) throws -> RoutePosition {
        try #require(RoutePosition.Locate(Coordinate(latitude: latitude, longitude: longitude), on: route))
    }

    @Test func StartOfTheRouteIsOnItAtZero() throws {
        let position = try Locate(latitude: 0, longitude: 0)

        #expect(position.distanceFromRoute < 1)
        #expect(position.distanceAlongRoute < 1)
    }

    @Test func CarBesideTheFirstLegIsMeasuredSideways() throws {
        // About 100 m north of the middle of the first leg.
        let position = try Locate(latitude: 0.0009, longitude: 0.005)

        #expect(abs(position.distanceFromRoute - 100) < 2)
        #expect(abs(position.distanceAlongRoute - Self.metresPerHundredthDegree / 2) < 2)
    }

    @Test func CarOnTheSecondLegCountsTheFirstLegToo() throws {
        let position = try Locate(latitude: 0.005, longitude: 0.01)

        #expect(position.distanceFromRoute < 1)
        #expect(abs(position.distanceAlongRoute - Self.metresPerHundredthDegree * 1.5) < 2)
    }

    @Test func CarPastTheEndIsMeasuredFromTheEnd() throws {
        let position = try Locate(latitude: 0.0109, longitude: 0.01)

        #expect(abs(position.distanceFromRoute - 100) < 2)
        #expect(abs(position.distanceAlongRoute - Self.metresPerHundredthDegree * 2) < 2)
    }

    @Test func NoRouteHasNoPosition() {
        #expect(RoutePosition.Locate(Coordinate(latitude: 0, longitude: 0), on: []) == nil)
    }

    @Test func RouteOfOnePointIsMeasuredFromThatPoint() throws {
        let point = Coordinate(latitude: 0.0009, longitude: 0)
        let position = try #require(RoutePosition.Locate(point, on: [Coordinate(latitude: 0, longitude: 0)]))

        #expect(abs(position.distanceFromRoute - 100) < 2)
        #expect(position.distanceAlongRoute == 0)
    }
}

/// The part of the route still ahead of a car, which is all the trip map draws, as in Apple Maps.
struct RouteAheadTests {
    private let route = [
        Coordinate(latitude: 0, longitude: 0),
        Coordinate(latitude: 0, longitude: 0.01),
        Coordinate(latitude: 0.01, longitude: 0.01)
    ]

    @Test func RouteAheadStartsWhereTheCarIs() {
        let ahead = RoutePosition.RouteAhead(of: Coordinate(latitude: 0.0001, longitude: 0.005), on: route)

        #expect(ahead.count == 3)
        #expect(abs(ahead[0].latitude) < 0.000_001)
        #expect(abs(ahead[0].longitude - 0.005) < 0.000_001)
        #expect(Array(ahead.dropFirst()) == Array(route.dropFirst()))
    }

    @Test func PassedCornerIsNoLongerDrawn() {
        let ahead = RoutePosition.RouteAhead(of: Coordinate(latitude: 0.005, longitude: 0.0101), on: route)

        #expect(ahead.count == 2)
        #expect(abs(ahead[0].latitude - 0.005) < 0.000_001)
        #expect(ahead.last == route.last)
    }

    @Test func NoRouteHasNothingAhead() {
        #expect(RoutePosition.RouteAhead(of: Coordinate(latitude: 0, longitude: 0), on: []).isEmpty)
    }
}
