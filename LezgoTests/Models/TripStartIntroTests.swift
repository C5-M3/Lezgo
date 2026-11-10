//
//  TripStartIntroTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The "Lez Go!" animation between Start Trip and the map: the robot rolls in, the letters grow as it passes, the
/// robot rolls out, and the camera goes through the hole of the O.
struct TripStartIntroTests {
    private typealias Letter = TripStartIntro.Letter

    @Test func RobotStartsOffScreenAndNoLetterShows() {
        let frame = TripStartIntro.FrameAt(0)

        #expect(frame.robotOffsetX < -300)
        #expect(Letter.allCases.allSatisfy { frame.Growth(of: $0) == 0 })
    }

    @Test func LettersGrowFromLeftToRightAsTheRobotPasses() {
        let frame = TripStartIntro.FrameAt(0.9)

        #expect(frame.Growth(of: .letterL) > 0)
        #expect(frame.Growth(of: .letterG) > 0)
        #expect(frame.Growth(of: .letterE) > 0)
        #expect(frame.Growth(of: .letterZ) == 0)
        #expect(frame.Growth(of: .letterO) == 0)
        #expect(frame.Growth(of: .bang) == 0)
    }

    @Test func RobotRestsUprightOnTheOOnceTheLogoIsComplete() {
        let frame = TripStartIntro.FrameAt(1.65)

        #expect(frame.robotOffsetX == 0)
        #expect(frame.robotRotationDegrees == 0)
        #expect(frame.robotScaleX == 1)
        #expect(frame.robotScaleY == 1)
        #expect(Letter.allCases.allSatisfy { frame.Growth(of: $0) == 1 })
    }

    @Test func HoleStaysClosedWhileTheRobotComesIn() {
        #expect(TripStartIntro.FrameAt(1.0).holeRadius == 0)
        #expect(TripStartIntro.FrameAt(1.6).holeRadius == 0)
    }

    @Test func RobotHidesTheHoleUntilItStartsToLeave() {
        let frame = TripStartIntro.FrameAt(TripStartIntro.robotLeaves - 0.01)

        #expect(frame.holeRadius == TripStartIntro.holeRadius)
        #expect(frame.robotOffsetX == 0)
    }

    @Test func RobotHasLeftBeforeTheCameraGoesThroughTheO() {
        let frame = TripStartIntro.FrameAt(TripStartIntro.zoomStarts)

        #expect(frame.robotOffsetX >= TripStartIntro.robotExitOffset)
        #expect(frame.logoZoom <= 1)
    }

    @Test func RobotBacksUpBeforeRollingOut() {
        let frame = TripStartIntro.FrameAt(TripStartIntro.robotLeaves + 0.14)

        #expect(frame.robotOffsetX < 0)
    }

    @Test func RobotBumpsTheBangOnItsWayOut() {
        let frame = TripStartIntro.FrameAt(TripStartIntro.bangBump + 0.07)

        #expect(frame.bangTiltDegrees > 10)
        #expect(TripStartIntro.FrameAt(TripStartIntro.zoomStarts).bangTiltDegrees.magnitude < 2)
    }

    @Test func HoleEdgeFollowsTheOAllTheWayThroughTheZoom() {
        for time in stride(from: TripStartIntro.zoomStarts, through: TripStartIntro.duration, by: 0.05) {
            let frame = TripStartIntro.FrameAt(time)

            #expect((frame.holeRadius - TripStartIntro.holeRadius * frame.logoZoom).magnitude < 0.001)
        }
    }

    @Test func LastFrameIsZoomedAllTheWay() {
        #expect(TripStartIntro.FrameAt(TripStartIntro.duration).logoZoom == TripStartIntro.finalZoom)
    }

    @Test func TripScreenAppearsBeforeTheYellowIsGone() {
        #expect(TripStartIntro.mapReveals > TripStartIntro.zoomStarts)
        #expect(TripStartIntro.mapReveals < TripStartIntro.duration)
    }

    @Test func TimesOutsideTheAnimationStayOnItsFirstAndLastFrame() {
        #expect(TripStartIntro.FrameAt(-5) == TripStartIntro.FrameAt(0))
        #expect(TripStartIntro.FrameAt(99) == TripStartIntro.FrameAt(TripStartIntro.duration))
    }

    // MARK: - When it plays

    private func Trip(status: TripStatus, startedSecondsAgo: Double?) -> Lezgo.Trip {
        let now = TripMapFixtures.now
        return Lezgo.Trip(
            id: TripMapFixtures.tripID,
            roomCode: "897654",
            status: status,
            leaderParticipantID: TripMapFixtures.agusID,
            currentWaypointIndex: 1,
            routeVersion: 1,
            createdAt: now.addingTimeInterval(-600),
            startedAt: startedSecondsAgo.map { now.addingTimeInterval(-$0) }
        )
    }

    @Test func PlaysWhenTheMapOpensFromTheTripRoomSession() {
        let trip = Trip(status: .lobby, startedSecondsAgo: nil)

        #expect(TripStartIntro.ShouldPlay(for: trip, at: TripMapFixtures.now))
    }

    @Test func PlaysForAMemberWhoseTripJustStarted() {
        let trip = Trip(status: .inTrip, startedSecondsAgo: 5)

        #expect(TripStartIntro.ShouldPlay(for: trip, at: TripMapFixtures.now))
    }

    @Test func PlaysWhenAnotherPhonesClockIsAheadOfThisOne() {
        let trip = Trip(status: .inTrip, startedSecondsAgo: -3)

        #expect(TripStartIntro.ShouldPlay(for: trip, at: TripMapFixtures.now))
    }

    @Test func DoesNotPlayWhenReopeningATripOnTheRoad() {
        let trip = Trip(status: .inTrip, startedSecondsAgo: 300)

        #expect(TripStartIntro.ShouldPlay(for: trip, at: TripMapFixtures.now) == false)
    }

    @Test func DoesNotPlayForAnInTripWithoutAStartTime() {
        let trip = Trip(status: .inTrip, startedSecondsAgo: nil)

        #expect(TripStartIntro.ShouldPlay(for: trip, at: TripMapFixtures.now) == false)
    }

    // MARK: Running the steps on the map

    /// What the steps did, in order, and how long each wait was.
    private final class Recorder {
        var steps: [String] = []
        var waits: [Double] = []
    }

    private func Steps(_ recorder: Recorder) -> [TripStartIntro.Step] {
        [
            TripStartIntro.Step(at: 1.5) { recorder.steps.append("map") },
            TripStartIntro.Step(at: 2.8) { recorder.steps.append("settle") },
            TripStartIntro.Step(at: 3.06) { recorder.steps.append("done") }
        ]
    }

    @Test func StepsRunInOrderAfterWaitingForTheirMoment() async {
        let recorder = Recorder()

        await TripStartIntro.RunSteps(Steps(recorder)) { recorder.waits.append($0) }

        #expect(recorder.steps == ["map", "settle", "done"])
        #expect(recorder.waits.map { ($0 * 100).rounded() / 100 } == [1.5, 1.3, 0.26])
    }

    /// SwiftUI can restart the map's task while it presents the map, which cancels the first run. A cancelled run
    /// must stop, not race through its steps: that removed the yellow before anyone saw it.
    @Test func ACancelledRunStopsWithoutRunningTheRemainingSteps() async {
        let recorder = Recorder()

        await TripStartIntro.RunSteps(Steps(recorder)) { _ in throw CancellationError() }

        #expect(recorder.steps.isEmpty)
    }
}
