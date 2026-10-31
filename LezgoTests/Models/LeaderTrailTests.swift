//
//  LeaderTrailTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The road the leader has driven, kept so members can follow it (`specs/UserStories.md` → US-06, "Footprint").
struct LeaderTrailTests {
    /// About 1 m of latitude.
    private static let metre = 1 / 111_320.0
    private let start = Coordinate(latitude: -7.27, longitude: 112.73)

    private func North(_ metres: Double) -> Coordinate {
        Coordinate(latitude: start.latitude + metres * Self.metre, longitude: start.longitude)
    }

    @Test func FirstPositionStartsTheTrail() {
        var trail = LeaderTrail()

        let isAdded = trail.Append(start)

        #expect(isAdded)
        #expect(trail.points == [start])
    }

    @Test func PositionsCloserThan20MetresAreSkipped() {
        // GPS noise while standing still would otherwise fill the trail with points in one place.
        var trail = LeaderTrail(points: [start])

        let isNoiseAdded = trail.Append(North(5))
        let isMoveAdded = trail.Append(North(25))

        #expect(isNoiseAdded == false)
        #expect(isMoveAdded)
        #expect(trail.points == [start, North(25)])
    }

    @Test func OldestPointsGoOnceTheTrailIsFull() {
        var trail = LeaderTrail()
        for step in 0...LeaderTrail.maximumPointCount {
            trail.Append(North(Double(step) * 30))
        }

        #expect(trail.points.count == LeaderTrail.maximumPointCount)
        #expect(trail.points.first == North(30))
    }
}
