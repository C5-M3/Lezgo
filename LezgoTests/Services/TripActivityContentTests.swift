//
//  TripActivityContentTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// What the trip's Live Activity says (ADR 0027).
@MainActor
struct TripActivityContentTests {
    private typealias Fixtures = TripMapFixtures
    private typealias Sample = TripActivityFixtures

    @Test func TitleNamesTheDestination() {
        #expect(TripActivityContent.Attributes(destinationName: "Pakuwon mall").title == "To Pakuwon mall")
    }

    @Test func DrivingShowsTheNextTurnAndTimeLeft() throws {
        let state = TripActivityContent.State(Sample.Input())
        #expect(state.stage == .driving)
        let turn = try #require(state.turn)
        #expect(turn.symbolName == "arrow.turn.up.right")
        #expect(turn.distanceText == "200 m")
        #expect(turn.instruction == "Turn right")
        #expect(state.timeLeftText == "1 hr, 20 min")
        #expect(state.arrivalTimeText == Sample.ArrivalClock(minutesLeft: 80))
    }

    @Test func CompactIslandGetsAShortTime() {
        #expect(TripActivityContent.State(Sample.Input()).shortTimeLeftText == "1:20")
        let soon = TripActivityContent.State(Sample.Input(guidance: Fixtures.Guidance(minutesLeft: 33)))
        #expect(soon.shortTimeLeftText == "33 min")
    }

    @Test func DetailShowsDistanceLeftAndArrivalTime() {
        var guidance = Fixtures.Guidance(minutesLeft: 80)
        guidance.distanceLeft = Measurement(value: 64, unit: .kilometers)
        let state = TripActivityContent.State(Sample.Input(guidance: guidance))
        #expect(state.detailText == "64 km · Arrive \(Sample.ArrivalClock(minutesLeft: 80))")
    }

    @Test func DetailWithoutDistanceLeftShowsOnlyTheArrivalTime() {
        let state = TripActivityContent.State(Sample.Input())
        #expect(state.detailText == "Arrive \(Sample.ArrivalClock(minutesLeft: 80))")
    }

    @Test func NoGuidanceYetIsLoading() {
        let state = TripActivityContent.State(Sample.Input(guidance: nil))
        #expect(state.stage == .loading)
        #expect(state.turn == nil)
        #expect(state.timeLeftText == nil)
    }

    @Test func ReroutingHidesTheTurnAndSaysSo() {
        let state = TripActivityContent.State(Sample.Input(isRerouting: true))
        #expect(state.stage == .rerouting)
        #expect(state.turn == nil)
        #expect(state.statusText == "Rerouting…")
    }

    @Test func HeadlineNamesTheNextStop() {
        #expect(TripActivityContent.State(Sample.Input()).headline == "Next stop · Ciputra World")
        let later = TripActivityContent.State(Sample.Input(currentWaypointIndex: 2))
        #expect(later.headline == "Next stop · Rest area KM 57")
    }

    @Test func HeadlineNamesTheDestinationOnTheLastLeg() {
        let state = TripActivityContent.State(Sample.Input(currentWaypointIndex: 3))
        #expect(state.headline == "To Pakuwon mall")
    }

    @Test func MemberFollowsTheLeader() {
        let state = TripActivityContent.State(Sample.Input())
        #expect(state.isLeader == false)
        #expect(state.groupText == "Following Agus")
        #expect(state.isGroupWarning == false)
        #expect(state.myColor == .blue)
    }

    @Test func LeaderCountsCarsOnRoute() {
        var leader = Sample.agus
        leader.isMe = true
        var budi = Sample.budi
        budi.isMe = false
        var citra = Sample.citra
        citra.isAlerting = true
        let state = TripActivityContent.State(Sample.Input(cars: [leader, budi, citra]))
        #expect(state.isLeader)
        #expect(state.groupText == "2/3 cars on route")
        #expect(state.isGroupWarning)
    }

    @Test func OfflineCarsAreNotOnRoute() {
        var leader = Sample.agus
        leader.isMe = true
        var budi = Sample.budi
        budi.isMe = false
        budi.isOffline = true
        let state = TripActivityContent.State(Sample.Input(cars: [leader, budi]))
        #expect(state.groupText == "1/2 cars on route")
    }

    @Test func AnotherCarsAlertUsesItsRobotTextAndDistance() throws {
        var citra = Sample.citra
        citra.isAlerting = true
        let banner = TripMapAlerts.Banner.otherCar(id: Fixtures.citraID, name: "Citra", alert: .offRoute)
        let input = Sample.Input(cars: [Sample.agus, Sample.budi, citra], alertBanner: banner)
        let state = TripActivityContent.State(input)
        let alert = try #require(state.alert)
        #expect(alert.text == "Citra has gone out of route")
        #expect(alert.shortText == "Off route")
        #expect(alert.color == .pink)
        #expect(alert.carName == "Citra")
        #expect(alert.detail?.hasSuffix("ahead of you") == true)
        #expect(state.robots.first { $0.id == Fixtures.citraID }?.isAlerting == true)
    }

    @Test func StoppedCarBehindTheLeaderSaysHowFarBehind() throws {
        var leader = Sample.agus
        leader.isMe = true
        var budi = Sample.budi
        budi.isMe = false
        let banner = TripMapAlerts.Banner.carStopped(id: Fixtures.citraID, name: "Citra")
        let state = TripActivityContent.State(Sample.Input(cars: [leader, budi, Sample.citra], alertBanner: banner))
        let alert = try #require(state.alert)
        #expect(alert.shortText == "Stopped")
        #expect(alert.detail?.hasSuffix("behind you") == true)
    }

    @Test func MyOwnAlertUsesMyRobot() throws {
        let state = TripActivityContent.State(Sample.Input(alertBanner: .mine(.offRoute)))
        let alert = try #require(state.alert)
        #expect(alert.color == .blue)
        #expect(alert.carName == "You")
        #expect(alert.shortText == "Off route")
        #expect(alert.detail == nil)
    }

    @Test func ArrivedShowsTheTitleCountAndWhatIsNext() throws {
        let progress = TripMapArrivalProgress(robots: [], arrivedCount: 3, totalCount: 4)
        let state = TripActivityContent.State(
            Sample.Input(arrivalCard: .waitingForEveryone, arrivalProgress: progress)
        )
        #expect(state.stage == .arrived)
        #expect(state.headline == "Pakuwon mall")
        let arrival = try #require(state.arrival)
        #expect(arrival.title == "You have arrived")
        #expect(arrival.countText == "3/4")
        #expect(arrival.detail == "Waiting for everyone to arrive")
        #expect(state.turn == nil)
    }

    @Test func MuteLabelFollowsTheMuteButton() {
        #expect(TripActivityContent.State(Sample.Input(isMuted: false)).muteLabel == "Mute")
        let muted = TripActivityContent.State(Sample.Input(isMuted: true))
        #expect(muted.isMuted)
        #expect(muted.muteLabel == "Unmute")
    }

    @Test func VeryLongStopNamesAreKeptWhole() {
        let name = "Rest area KM 57 Jalan Tol Jagorawi arah Puncak Bogor Jawa Barat"
        var stop = Fixtures.checkpoint
        stop.name = name
        let state = TripActivityContent.State(Sample.Input(waypoints: [Fixtures.startPoint, stop, Sample.lastStop]))
        #expect(state.headline == "Next stop · \(name)")
    }
}
