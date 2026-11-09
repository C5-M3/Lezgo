//
//  TripMapArrivalMotionTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Testing
@testable import Lezgo

/// A new robot rolls in slowly from the left and gently pushes the row to the right.
struct TripMapArrivalMotionTests {
    private typealias Motion = TripMapArrivalMotion

    @Test func RobotStartsAwayAndEndsInItsPlace() {
        #expect(Motion.RollProgress(at: 0) == 0)
        #expect(Motion.RollProgress(at: Motion.rollDuration) == 1)
        #expect(Motion.RollProgress(at: 99) == 1)
    }

    @Test func RobotSlowsDownAsItArrives() {
        let firstHalf = Motion.RollProgress(at: Motion.rollDuration / 2)
        let secondHalf = 1 - firstHalf

        #expect(firstHalf > secondHalf)
    }

    @Test func TheRowStaysStillUntilTheRobotTouchesIt() {
        #expect(Motion.PushOffset(at: 0, rank: 0) == 0)
        #expect(Motion.PushOffset(at: Motion.contact, rank: 0) == 0)
    }

    @Test func ThePushIsSmallAndGoesToTheRight() {
        let times = stride(from: 0.0, through: Motion.duration, by: 0.01)
        let offsets = times.map { Motion.PushOffset(at: $0, rank: 0) }

        #expect(offsets.allSatisfy { $0 >= 0 })
        #expect(offsets.max() == Motion.pushDistance)
        #expect(Motion.pushDistance <= 8)
    }

    @Test func ThePushReachesTheFartherRobotsSlightlyLater() {
        let time = Motion.contact + 0.1

        #expect(Motion.PushOffset(at: time, rank: 0) > Motion.PushOffset(at: time, rank: 1))
        #expect(Motion.PushOffset(at: time, rank: 1) > Motion.PushOffset(at: time, rank: 2))
    }

    @Test(arguments: 0..<4)
    func EveryRobotIsBackInPlaceWhenTheAnimationEnds(rank: Int) {
        #expect(Motion.PushOffset(at: Motion.duration, rank: rank) == 0)
    }

    @Test func RollingADistanceTurnsTheRobotAccordingly() {
        // One full turn over the robot's own circumference.
        #expect((Motion.RollDegrees(over: .pi * Motion.robotSize) - 360).magnitude < 0.001)
        #expect(Motion.RollDegrees(over: 0) == 0)
    }
}
