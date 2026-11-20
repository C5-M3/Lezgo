//
//  LoopingPositionTests.swift
//  LezgoTests
//

import Testing
@testable import Lezgo

struct LoopingPositionTests {
    private let three = LoopingPosition(count: 3)

    @Test func CardInTheMiddleHasNoOffset() {
        #expect(three.Offset(of: 0, from: 0) == 0)
        #expect(three.Offset(of: 1, from: 1) == 0)
    }

    @Test func LastCardIsOneStepBeforeTheFirst() {
        #expect(three.Offset(of: 2, from: 0) == -1)
        #expect(three.Offset(of: 1, from: 0) == 1)
    }

    @Test func OffsetFollowsAPositionBetweenTwoCards() {
        #expect(abs(three.Offset(of: 0, from: 2.4) - 0.6) < 0.0001)
        #expect(abs(three.Offset(of: 2, from: 2.4) + 0.4) < 0.0001)
    }

    @Test func OffsetWrapsForPositionsPastTheEnds() {
        #expect(three.Offset(of: 0, from: 3) == 0)
        #expect(three.Offset(of: 2, from: -1) == 0)
    }

    @Test func NearestIndexWrapsAroundBothEnds() {
        #expect(three.NearestIndex(to: -0.6) == 2)
        #expect(three.NearestIndex(to: 3.2) == 0)
        #expect(three.NearestIndex(to: 1.4) == 1)
    }

    @Test func SlowShortDragComesBackToTheSameCard() {
        #expect(three.RestingPosition(from: 0, releasedAt: 0.2, velocity: 0) == 0)
    }

    @Test func DragPastHalfACardMovesToTheNextCard() {
        #expect(three.RestingPosition(from: 0, releasedAt: 0.6, velocity: 0) == 1)
    }

    @Test func ShortFastFlickMovesToTheNextCard() {
        #expect(three.RestingPosition(from: 0, releasedAt: 0.1, velocity: 5) == 1)
    }

    @Test func ASwipeNeverMovesMoreThanOneCard() {
        #expect(three.RestingPosition(from: 0, releasedAt: 0.1, velocity: 50) == 1)
        #expect(three.RestingPosition(from: 0, releasedAt: -0.1, velocity: -50) == -1)
    }

    @Test func TargetTakesTheShortWayRoundTheEnd() {
        #expect(three.Target(for: 0, from: 2) == 3)
        #expect(three.Target(for: 2, from: 0) == -1)
    }

    @Test func TargetForTheCardInTheMiddleStaysPut() {
        #expect(three.Target(for: 1, from: 1.2) == 1)
    }

    @Test func SingleCardNeverMoves() {
        let one = LoopingPosition(count: 1)

        #expect(one.Offset(of: 0, from: 5.3) == 0)
        #expect(one.NearestIndex(to: 5.3) == 0)
        #expect(one.RestingPosition(from: 0, releasedAt: 0.9, velocity: 9) == 0)
    }
}
