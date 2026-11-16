//
//  HomeSplitMotionTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 16/11/26.
//

import Testing
@testable import Lezgo

/// The split-screen Home moves as a pure function of progress, so its keyframes match the Sketch frames on the
/// "Home Options" page (issue #329). Positions are in design points on the 402 × 874 frame.
struct HomeSplitMotionTests {
    private typealias Motion = HomeSplitMotion

    private func IsClose(_ value: Double, _ expected: Double, within tolerance: Double = 0.5) -> Bool {
        abs(value - expected) <= tolerance
    }

    @Test func LeadHomeMatchesTheDesign() {
        let frame = Motion.FrameAt(.lead, progress: 0)

        #expect(frame.topSlab == Motion.Edge(left: 550, right: 480))
        #expect(frame.bottomSlab.right >= Motion.canvasHeight)
        #expect(frame.leadWord == Motion.Placement(x: 24, y: 144, scale: 1, opacity: 1))
        #expect(frame.joinWord == Motion.Placement(x: 24, y: 588, scale: 1, opacity: 1))
    }

    @Test func BothFlowsStartFromTheSameHome() {
        #expect(Motion.FrameAt(.lead, progress: 0) == Motion.FrameAt(.join, progress: 0))
    }

    @Test func DestinationsStayHiddenUntilTheirWipeStarts() {
        let lead = Motion.FrameAt(.lead, progress: Motion.RevealStart(of: .lead))
        let join = Motion.FrameAt(.join, progress: Motion.RevealStart(of: .join))

        #expect(lead.leadDestination.left <= 0)
        #expect(join.joinDestination.right >= Motion.canvasHeight)
    }

    @Test func LeadEndsWithSetRouteCoveringTheScreen() {
        let frame = Motion.FrameAt(.lead, progress: 1)

        // Set Route comes in from the top, so its lower edge must be past the bottom on both sides.
        #expect(frame.leadDestination.right >= Motion.canvasHeight)
        #expect(frame.leadDestination.left >= Motion.canvasHeight)
    }

    @Test func JoinEndsWithRoomCodeCoveringTheScreen() {
        let frame = Motion.FrameAt(.join, progress: 1)

        // Enter room code comes in from the bottom, so its upper edge must be past the top on both sides.
        #expect(frame.joinDestination.left <= 0)
        #expect(frame.joinDestination.right <= 0)
    }

    @Test func JoinHomeMatchesTheDesign() {
        let frame = Motion.FrameAt(.join, progress: Motion.joinHome)

        #expect(frame.topSlab.left <= 0)
        #expect(IsClose(frame.bottomSlab.left, 383))
        #expect(IsClose(frame.bottomSlab.right, 335))
        #expect(IsClose(frame.leadWord.x, 22) && IsClose(frame.leadWord.y, 146))
        #expect(IsClose(frame.leadWord.scale, 149.0 / 297.0, within: 0.01))
        #expect(frame.leadWord.opacity == 1)
        #expect(IsClose(frame.joinWord.x, 10) && IsClose(frame.joinWord.y, 409))
        #expect(IsClose(frame.joinWord.scale, 2, within: 0.01))
    }

    @Test func TheCrewHasLandedOnTheJoinHome() {
        let frame = Motion.FrameAt(.join, progress: Motion.joinHome)

        #expect(frame.crew.count == Motion.crewCount)
        for pose in frame.crew {
            #expect(IsClose(pose.offset, 0, within: 0.01))
            #expect(IsClose(pose.scale, 1, within: 0.01))
        }
    }

    @Test func TheCrewIsBelowItsPlaceOnTheLeadHome() {
        let frame = Motion.FrameAt(.join, progress: 0)

        #expect(frame.crew.allSatisfy { $0.offset > 0 })
    }

    @Test func TheLeadMascotStaysUprightWhileItSprings() {
        for step in 0...20 {
            let frame = Motion.FrameAt(.lead, progress: Double(step) / 20)
            #expect(frame.mascot.rotation == 0)
        }
    }

    @Test func TheLeadMascotRisesIntoTheOpenSpace() {
        let rest = Motion.FrameAt(.lead, progress: 0).mascot
        let risen = Motion.FrameAt(.lead, progress: Motion.RevealStart(of: .lead)).mascot

        #expect(rest.offset == 0)
        #expect(risen.offset < 0)
    }

    @Test func DurationFollowsTheDistanceTravelled() {
        let back = Motion.Duration(of: .join, from: 1, to: Motion.joinHome)

        #expect(IsClose(back, (1 - Motion.joinHome) * Motion.TotalDuration(of: .join), within: 0.0001))
        #expect(Motion.Duration(of: .lead, from: 0.5, to: 0.5) == 0)
    }
}
