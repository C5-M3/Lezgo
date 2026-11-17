//
//  HomeSplitMotionTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 16/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The split-screen Home moves as a pure function of progress, so its keyframes match the Sketch frames on the
/// "Home Options" page and the approved motion mockups (issue #329). Positions are in design points on the
/// 402 × 874 frame.
struct HomeSplitMotionTests {
    private typealias Motion = HomeSplitMotion

    private func IsClose(_ value: Double, _ expected: Double, within tolerance: Double = 0.5) -> Bool {
        abs(value - expected) <= tolerance
    }

    /// The progress of the join flow at `time` of the mockup's join timeline, from the JOIN home (0.43) to 1.
    private func JoinProgress(atMockupTime time: Double) -> Double {
        Motion.joinHome + (time - 0.43) / 0.57 * (1 - Motion.joinHome)
    }

    /// The progress of the Swing at `fraction` of its 680 ms, from the LEAD home to the JOIN home.
    private func SwingProgress(_ fraction: Double) -> Double {
        fraction * Motion.joinHome
    }

    // MARK: - Rest frames

    @Test func LeadHomeMatchesTheDesign() {
        let frame = Motion.FrameAt(.lead, progress: 0)

        #expect(frame.topSlab == Motion.Edge(left: 550, right: 480))
        #expect(frame.bottomSlab.right >= Motion.canvasHeight)
        #expect(frame.leadWord == Motion.Placement(x: 24, y: 144, scale: 1, opacity: 1))
        #expect(frame.joinWord == Motion.Placement(x: 24, y: 588, scale: 1, opacity: 1))
        #expect(frame.sheet == nil)
    }

    @Test func EveryFlowStartsFromTheSameLeadHome() {
        let lead = Motion.FrameAt(.lead, progress: 0)

        #expect(Motion.FrameAt(.join, progress: 0) == lead)
        #expect(Motion.FrameAt(.swingBack, progress: 0) == lead)
    }

    @Test func TheSwingBackStartsFromTheJoinHome() {
        let joinHome = Motion.FrameAt(.join, progress: Motion.joinHome)
        #expect(Motion.FrameAt(.swingBack, progress: Motion.joinHome) == joinHome)
    }

    @Test func JoinHomeMatchesTheDesign() {
        let frame = Motion.FrameAt(.join, progress: Motion.joinHome)

        #expect(frame.sheet == nil)
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
            #expect(pose.opacity == 1)
        }
    }

    @Test func TheCrewIsBelowItsPlaceOnTheLeadHome() {
        let frame = Motion.FrameAt(.join, progress: 0)

        #expect(frame.crew.allSatisfy { $0.offset > 0 })
    }

    // MARK: - Swing

    @Test func DuringTheSwingTheYellowIsOneSheet() {
        for step in 1..<20 {
            let frame = Motion.FrameAt(.join, progress: SwingProgress(Double(step) / 20))
            #expect(frame.sheet != nil)
            let back = Motion.FrameAt(.swingBack, progress: SwingProgress(Double(step) / 20))
            #expect(back.sheet != nil)
        }
    }

    @Test func TheSwingStartsOnTheLeadEdgeAndEndsOnTheJoinEdge() throws {
        let start = try #require(Motion.FrameAt(.join, progress: SwingProgress(0.0001)).sheet)
        let end = try #require(Motion.FrameAt(.join, progress: SwingProgress(0.9999)).sheet)

        #expect(IsClose(start.x, 201) && IsClose(start.y, 515))
        #expect(IsClose(start.angle, Motion.leadTilt, within: 0.01))
        #expect(IsClose(end.x, 201) && IsClose(end.y, 359))
        #expect(IsClose(end.angle, Motion.joinTilt + .pi, within: 0.01))
    }

    @Test func TheSwingTurnsClockwiseAndTheWayBackTurnsCounterClockwise() throws {
        let forward = try [0.2, 0.4, 0.6].map { fraction in
            try #require(Motion.FrameAt(.join, progress: SwingProgress(fraction)).sheet).angle
        }
        // The swing back runs from the JOIN home (progress `joinHome`) down to the LEAD home (0).
        let back = try [0.2, 0.4, 0.6].map { fraction in
            try #require(Motion.FrameAt(.swingBack, progress: SwingProgress(1 - fraction)).sheet).angle
        }

        #expect(forward[0] < forward[1] && forward[1] < forward[2])
        #expect(back[0] > back[1] && back[1] > back[2])
        // Halfway the yellow faces the right edge in both directions.
        let halfway = try #require(Motion.FrameAt(.join, progress: SwingProgress(0.5)).sheet).angle
        let halfwayBack = try #require(Motion.FrameAt(.swingBack, progress: SwingProgress(0.5)).sheet).angle
        #expect(sin(halfway) > 0.5)
        #expect(sin(halfwayBack) > 0.5)
    }

    @Test func TheLeadMascotSlipsOutToTheRightAsTheSwingStarts() {
        let early = Motion.FrameAt(.join, progress: SwingProgress(0.2)).mascot
        let gone = Motion.FrameAt(.join, progress: SwingProgress(0.45)).mascot

        #expect(early.shift > 0 && early.shift < 340)
        #expect(IsClose(gone.shift, 340, within: 0.001))
    }

    @Test func TheCrewOnlyPopsInDuringTheSecondHalfOfTheSwing() {
        let early = Motion.FrameAt(.join, progress: SwingProgress(0.49))
        let late = Motion.FrameAt(.join, progress: SwingProgress(0.9))

        #expect(early.crew.allSatisfy { $0.opacity == 0 })
        // The big yellow one at the front of the pile comes first.
        #expect(late.crew[4].opacity == 1)
    }

    @Test func OnTheWayBackTheCrewDucksAwayAndTheMascotSpringsBack() {
        let ducked = Motion.FrameAt(.swingBack, progress: SwingProgress(1 - 0.4))
        let springing = Motion.FrameAt(.swingBack, progress: SwingProgress(1 - 0.75))

        #expect(ducked.crew.allSatisfy { $0.opacity == 0 })
        #expect(springing.mascot.shift < 340)
        #expect(Motion.FrameAt(.swingBack, progress: SwingProgress(1 - 0.3)).mascot.shift == 340)
    }

    // MARK: - Tap to the next screen

    @Test func SetRouteStartsToWipeInAtThirtyPercent() {
        #expect(Motion.FrameAt(.lead, progress: 0.30).leadDestination.left <= 0)
        #expect(Motion.FrameAt(.lead, progress: 0.32).leadDestination.left > 0)
    }

    @Test func RoomCodeStartsToWipeInAtFiftySixPercentOfTheJoinTimeline() {
        let start = Motion.FrameAt(.join, progress: JoinProgress(atMockupTime: 0.555))
        let after = Motion.FrameAt(.join, progress: JoinProgress(atMockupTime: 0.58))

        #expect(start.joinDestination.right >= Motion.canvasHeight)
        #expect(after.joinDestination.right < Motion.canvasHeight)
    }

    @Test func TheYellowFillsWhileRoomCodeFollows() {
        // At 0.60 of the join timeline the yellow is still filling while Enter room code already comes in.
        let frame = Motion.FrameAt(.join, progress: JoinProgress(atMockupTime: 0.60))

        #expect(frame.bottomSlab.left > -2)
        #expect(frame.joinDestination.right < Motion.canvasHeight)
    }

    @Test func LeadEndsWithSetRouteCoveringTheScreen() {
        let frame = Motion.FrameAt(.lead, progress: 1)

        // Set Route comes in from the top, so its lower edge must be past the bottom on both sides.
        #expect(frame.leadDestination.right >= Motion.canvasHeight)
        #expect(frame.leadDestination.left >= Motion.canvasHeight)
        #expect(frame.leadDestinationOffset == 0)
    }

    @Test func JoinEndsWithRoomCodeCoveringTheScreen() {
        let frame = Motion.FrameAt(.join, progress: 1)

        // Enter room code comes in from the bottom, so its upper edge must be past the top on both sides.
        #expect(frame.joinDestination.left <= 0)
        #expect(frame.joinDestination.right <= 0)
        #expect(frame.joinDestinationOffset == 0)
    }

    @Test func TheLeadMascotStaysUprightWhileItSprings() {
        for step in 0...20 {
            let frame = Motion.FrameAt(.lead, progress: Double(step) / 20)
            #expect(frame.mascot.rotation == 0)
        }
    }

    @Test func TheLeadMascotRisesIntoTheOpenSpace() {
        let rest = Motion.FrameAt(.lead, progress: 0).mascot
        let risen = Motion.FrameAt(.lead, progress: 0.30).mascot

        #expect(rest.offset == 0)
        #expect(risen.offset < 0)
    }

    // MARK: - Durations

    @Test func TheMotionsTakeAsLongAsInTheMockup() {
        #expect(IsClose(Motion.TotalDuration(of: .lead), 1.05, within: 0.0001))
        #expect(IsClose(Motion.Duration(of: .join, from: 0, to: Motion.joinHome), 0.68, within: 0.0001))
        #expect(IsClose(Motion.Duration(of: .join, from: Motion.joinHome, to: 1), 0.855, within: 0.0001))
        #expect(IsClose(Motion.Duration(of: .swingBack, from: Motion.joinHome, to: 0), 0.68, within: 0.0001))
    }

    @Test func DurationFollowsTheDistanceTravelled() {
        let back = Motion.Duration(of: .join, from: 1, to: Motion.joinHome)

        #expect(IsClose(back, (1 - Motion.joinHome) * Motion.TotalDuration(of: .join), within: 0.0001))
        #expect(Motion.Duration(of: .lead, from: 0.5, to: 0.5) == 0)
    }

    // MARK: - Fit

    @Test func TheDesignFillsAPortraitPhone() {
        let fit = Motion.FitOn(width: 402, height: 874)
        #expect(fit == Motion.Fit(scale: 1, left: 0))
    }

    @Test func TheDesignIsNeverStretchedOnAWiderPhone() {
        let fit = Motion.FitOn(width: 440, height: 874)
        #expect(fit.scale == 1)
        #expect(fit.left == 19)
    }

    @Test func TheMascotsStillPeekInFromTheRightEdgeWhenTheScreenIsSideways() {
        let fit = Motion.FitOn(width: 956, height: 437)
        #expect(fit.rightPinnedLeft + Motion.canvasWidth * fit.scale == 956)
    }

    @Test func TheDesignFitsTheHeightAndIsCentredWhenTheScreenIsSideways() {
        let fit = Motion.FitOn(width: 956, height: 437)
        #expect(fit.scale == 0.5)
        #expect(fit.left == 377.5)
    }
}
