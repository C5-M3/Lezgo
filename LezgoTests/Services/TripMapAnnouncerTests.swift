//
//  TripMapAnnouncerTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// What the trip map says out loud, and when (`specs/UserStories.md` → US-06, "Sound").
struct TripMapAnnouncerTests {
    private typealias Fixtures = TripMapFixtures
    private typealias Announcement = TripMapAnnouncer.Announcement

    private func Turn(
        _ meters: Double,
        instruction: String = "Turn right",
        direction: TripMapGuidance.TurnDirection = .right
    ) -> TripMapGuidance {
        var guidance = Fixtures.Guidance()
        guidance.instruction = instruction
        guidance.direction = direction
        guidance.distanceToTurn = Measurement(value: meters, unit: .meters)
        return guidance
    }

    /// Every announcement after driving through `distances` to the same turn.
    private func Announcements(driving distances: [Double]) -> [Announcement] {
        var announcer = TripMapAnnouncer()
        return distances.flatMap { announcer.Update(guidance: Turn($0), banner: nil, notice: nil) }
    }

    // MARK: Turns

    @Test func ATurnFarAwayIsSpokenAt500200AndTheTurn() {
        let announcements = Announcements(driving: [800, 650, 490, 350, 195, 100, 25, 5])

        #expect(announcements == [
            .turn(instruction: "Turn right", meters: 500),
            .turn(instruction: "Turn right", meters: 200),
            .turn(instruction: "Turn right", meters: nil)
        ])
    }

    @Test func NothingIsSpokenWhileTheTurnIsFurtherThan500Metres() {
        #expect(Announcements(driving: [2_000, 1_200, 700, 520]).isEmpty)
    }

    @Test func ATurnFirstSeenCloserThan500SkipsThe500Call() {
        let announcements = Announcements(driving: [420, 300, 190, 20])

        #expect(announcements == [
            .turn(instruction: "Turn right", meters: 200),
            .turn(instruction: "Turn right", meters: nil)
        ])
    }

    @Test func ATurnFirstSeenUnder200SaysHowFarItIsRoundedTo50() {
        #expect(Announcements(driving: [140]) == [.turn(instruction: "Turn right", meters: 150)])
    }

    @Test func ATurnFirstSeenAtTheTurnIsSpokenOnce() {
        #expect(Announcements(driving: [20, 10, 0]) == [.turn(instruction: "Turn right", meters: nil)])
    }

    @Test func GPSNoiseAroundAThresholdDoesNotRepeatTheCall() {
        let announcements = Announcements(driving: [250, 198, 205, 199, 190])

        #expect(announcements == [.turn(instruction: "Turn right", meters: 200)])
    }

    @Test func ANewInstructionIsANewTurn() {
        var announcer = TripMapAnnouncer()
        _ = announcer.Update(guidance: Turn(20), banner: nil, notice: nil)

        let next = announcer.Update(
            guidance: Turn(180, instruction: "Turn left onto Ahmad Yani Street", direction: .left),
            banner: nil,
            notice: nil
        )

        #expect(next == [.turn(instruction: "Turn left onto Ahmad Yani Street", meters: 200)])
    }

    @Test func TheSameInstructionFurtherAwayIsTheNextTurn() {
        var announcer = TripMapAnnouncer()
        _ = announcer.Update(guidance: Turn(20), banner: nil, notice: nil)

        let next = announcer.Update(guidance: Turn(600), banner: nil, notice: nil)
            + announcer.Update(guidance: Turn(480), banner: nil, notice: nil)

        #expect(next == [.turn(instruction: "Turn right", meters: 500)])
    }

    @Test func NoGuidanceSaysNothing() {
        var announcer = TripMapAnnouncer()

        #expect(announcer.Update(guidance: nil, banner: nil, notice: nil).isEmpty)
    }

    // MARK: Alerts

    @Test func ANewBannerPlaysTheAlertOnce() {
        var announcer = TripMapAnnouncer()
        let banner = TripMapAlerts.Banner.mine(.offRoute)

        let first = announcer.Update(guidance: nil, banner: banner, notice: nil)
        let second = announcer.Update(guidance: nil, banner: banner, notice: nil)

        #expect(first == [.alert(message: String(localized: banner.message))])
        #expect(second.isEmpty)
    }

    @Test func ABannerThatEndsAndHappensAgainPlaysAgain() {
        var announcer = TripMapAnnouncer()
        let banner = TripMapAlerts.Banner.mine(.offRoute)
        _ = announcer.Update(guidance: nil, banner: banner, notice: nil)
        _ = announcer.Update(guidance: nil, banner: nil, notice: nil)

        let again = announcer.Update(guidance: nil, banner: banner, notice: nil)

        #expect(again == [.alert(message: String(localized: banner.message))])
    }

    @Test func ABannerShownAgainAfterAnotherOneIsNotRepeated() {
        var announcer = TripMapAnnouncer()
        let aheadOfLeader = TripMapAlerts.Banner.otherCar(id: Fixtures.citraID, name: "Citra", alert: .aheadOfLeader)
        let offRoute = TripMapAlerts.Banner.mine(.offRoute)
        _ = announcer.Update(guidance: nil, banner: aheadOfLeader, notice: nil)
        _ = announcer.Update(guidance: nil, banner: offRoute, notice: nil)

        let back = announcer.Update(guidance: nil, banner: aheadOfLeader, notice: nil)

        #expect(back.isEmpty)
    }

    @Test func AStoppedCarPlaysTheAlert() {
        var announcer = TripMapAnnouncer()
        let banner = TripMapAlerts.Banner.carStopped(id: Fixtures.citraID, name: "Citra")

        #expect(announcer.Update(guidance: nil, banner: banner, notice: nil) == [
            .alert(message: String(localized: banner.message))
        ])
    }

    // MARK: Notices

    @Test(arguments: [TripMapNotice.rerouteFailed, .leaderOffline(name: "Agus")])
    func AnUrgentNoticePlaysTheAlert(notice: TripMapNotice) {
        var announcer = TripMapAnnouncer()

        let announcements = announcer.Update(guidance: nil, banner: nil, notice: notice)

        #expect(announcements == [.alert(message: notice.Message(timeLeft: nil))])
    }

    @Test(arguments: [TripMapNotice.newRoute(leaderName: "Agus"), .routeUpdated(leaderName: nil)])
    func ARouteChangeIsSpokenWithoutTheChime(notice: TripMapNotice) {
        var announcer = TripMapAnnouncer()

        let first = announcer.Update(guidance: nil, banner: nil, notice: notice)
        let second = announcer.Update(guidance: nil, banner: nil, notice: notice)

        #expect(first == [.routeChanged(notice)])
        #expect(second.isEmpty)
    }

    @Test func AnAlertComesBeforeTheTurn() {
        var announcer = TripMapAnnouncer()
        let banner = TripMapAlerts.Banner.mine(.offRoute)

        let announcements = announcer.Update(guidance: Turn(150), banner: banner, notice: nil)

        #expect(announcements == [
            .alert(message: String(localized: banner.message)),
            .turn(instruction: "Turn right", meters: 150)
        ])
    }

    // MARK: Spoken text

    @Test func TheSpokenTextOfATurnStartsWithTheDistance() {
        let announcement = Announcement.turn(instruction: "Turn right", meters: 200)

        let text = announcement.SpokenText(locale: Locale(identifier: "en_ID"))

        #expect(text == "In 200 meters, turn right")
    }

    @Test func TheSpokenTextAtTheTurnIsTheInstruction() {
        #expect(Announcement.turn(instruction: "Turn right", meters: nil).SpokenText() == "Turn right")
    }

    @Test func TheSpokenTextOfARouteChangeIsShort() {
        let notice = TripMapNotice.newRoute(leaderName: "Agus")

        #expect(Announcement.routeChanged(notice).SpokenText() == String(localized: .tripMapNoticeNewRoute))
    }

    @Test func OnlyAnAlertPlaysTheChime() {
        #expect(Announcement.alert(message: "Agus is offline").playsChime)
        #expect(Announcement.turn(instruction: "Turn right", meters: nil).playsChime == false)
        #expect(Announcement.routeChanged(.routeUpdated(leaderName: nil)).playsChime == false)
    }
}
