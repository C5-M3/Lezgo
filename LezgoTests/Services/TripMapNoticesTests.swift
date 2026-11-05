//
//  TripMapNoticesTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The banners about the trip itself: a new route, a failed reroute, an offline leader and a new leader
/// (`specs/UserStories.md` → US-06, "Route changes" and "Leader offline").
struct TripMapNoticesTests {
    private typealias Fixtures = TripMapFixtures

    private func State(
        leaderSecondsAgo: Double = 1,
        routeVersion: Int = 1,
        waypoints: [Waypoint]? = nil,
        leaderID: UUID = Fixtures.agusID,
        includesCitra: Bool = true
    ) -> TripState {
        var cars = [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus", lastSeenSecondsAgo: leaderSecondsAgo),
            Fixtures.Car(id: Fixtures.budiID, name: "Budi")
        ]
        if includesCitra { cars.append(Fixtures.Car(id: Fixtures.citraID, name: "Citra")) }
        var state = Fixtures.State(cars: cars)
        state.trip.routeVersion = routeVersion
        state.trip.leaderParticipantID = leaderID
        if let waypoints { state.waypoints = waypoints }
        return state
    }

    private func Notice(
        after states: [TripState],
        me: UUID = Fixtures.budiID,
        rerouteFailed: Bool = false
    ) -> TripMapNotice? {
        var notices = TripMapNotices()
        states.forEach { notices.Update($0) }
        return notices.Notice(in: states[states.count - 1], me: me, rerouteFailed: rerouteFailed, at: Fixtures.now)
    }

    /// The same stops under a new start point, as an automatic reroute saves them.
    private func ReroutedWaypoints() -> [Waypoint] {
        var start = Fixtures.startPoint
        start.name = "Current Location"
        start.coordinate = Coordinate(latitude: -7.27, longitude: 112.70)
        return [start, Fixtures.checkpoint, Fixtures.destination]
    }

    // MARK: New route

    @Test func NothingOnTheFirstState() {
        #expect(Notice(after: [State()]) == nil)
    }

    @Test func AReroutedTripTellsMembersWhoTheyFollow() {
        let notice = Notice(after: [State(), State(routeVersion: 2, waypoints: ReroutedWaypoints())])

        #expect(notice == .newRoute(leaderName: "Agus"))
    }

    @Test func TheLeaderIsNotToldToFollowThemselves() {
        let notice = Notice(
            after: [State(), State(routeVersion: 2, waypoints: ReroutedWaypoints())],
            me: Fixtures.agusID
        )

        #expect(notice == .newRoute(leaderName: nil))
    }

    @Test func ChangedStopsSayTheRouteWasUpdated() {
        var newDestination = Fixtures.destination
        newDestination.name = "Pakuwon city mall"

        let notice = Notice(after: [
            State(),
            State(routeVersion: 2, waypoints: [Fixtures.startPoint, Fixtures.checkpoint, newDestination])
        ])

        #expect(notice == .routeUpdated(leaderName: "Agus"))
    }

    @Test func SeveralRoutesInARowShowOnlyTheLatest() {
        var newDestination = Fixtures.destination
        newDestination.name = "Pakuwon city mall"

        let notice = Notice(after: [
            State(),
            State(routeVersion: 2, waypoints: [Fixtures.startPoint, Fixtures.checkpoint, newDestination]),
            State(routeVersion: 3, waypoints: [Fixtures.startPoint, Fixtures.checkpoint, newDestination])
        ])

        #expect(notice == .newRoute(leaderName: "Agus"))
    }

    @Test func ANewRouteNoticeCanBeClosed() throws {
        var notices = TripMapNotices()
        let state = State(routeVersion: 2, waypoints: ReroutedWaypoints())
        notices.Update(State())
        notices.Update(state)
        let me = Fixtures.budiID

        notices.Close(try #require(notices.Notice(in: state, me: me, rerouteFailed: false, at: Fixtures.now)))

        #expect(notices.Notice(in: state, me: me, rerouteFailed: false, at: Fixtures.now) == nil)
    }

    // MARK: Failed reroute

    @Test func AFailedRerouteOnlyShowsOnTheLeadersPhone() {
        #expect(Notice(after: [State()], me: Fixtures.agusID, rerouteFailed: true) == .rerouteFailed)
        #expect(Notice(after: [State()], me: Fixtures.budiID, rerouteFailed: true) == nil)
    }

    // MARK: Leader offline

    @Test(arguments: [
        (seconds: 120.0, notice: TripMapNotice?.none),
        (121, .leaderOffline(name: "Agus", canPickNewLeader: false)),
        (299, .leaderOffline(name: "Agus", canPickNewLeader: false)),
        (300, .leaderOffline(name: "Agus", canPickNewLeader: true))
    ])
    func AnOfflineLeaderIsShownAndCanBeReplacedAfterFiveMinutes(seconds: Double, notice: TripMapNotice?) {
        #expect(Notice(after: [State(leaderSecondsAgo: seconds)]) == notice)
    }

    @Test func TheBannerGoesWhenTheLeaderIsBack() {
        let notice = Notice(after: [State(leaderSecondsAgo: 180), State(leaderSecondsAgo: 1)])

        #expect(notice == nil)
    }

    @Test func TheLeadersOwnPhoneDoesNotSayTheLeaderIsOffline() {
        #expect(Notice(after: [State(leaderSecondsAgo: 300)], me: Fixtures.agusID) == nil)
    }

    @Test func ClosedOfflineBannerComesBackWhenPickingBecomesPossible() throws {
        var notices = TripMapNotices()
        let early = State(leaderSecondsAgo: 180)
        let late = State(leaderSecondsAgo: 300)
        let me = Fixtures.budiID
        notices.Update(early)
        notices.Close(try #require(notices.Notice(in: early, me: me, rerouteFailed: false, at: Fixtures.now)))
        #expect(notices.Notice(in: early, me: me, rerouteFailed: false, at: Fixtures.now) == nil)

        notices.Update(late)

        #expect(
            notices.Notice(in: late, me: me, rerouteFailed: false, at: Fixtures.now)
                == .leaderOffline(name: "Agus", canPickNewLeader: true)
        )
    }

    @Test func AnOfflineLeaderComesBeforeANewRoute() {
        let notice = Notice(after: [
            State(leaderSecondsAgo: 180),
            State(leaderSecondsAgo: 180, routeVersion: 2, waypoints: ReroutedWaypoints())
        ])

        #expect(notice == .leaderOffline(name: "Agus", canPickNewLeader: false))
    }

    // MARK: New leader

    @Test func EveryoneIsToldWhoTheNewLeaderIs() {
        let notice = Notice(after: [State(), State(leaderID: Fixtures.citraID)])

        #expect(notice == .newLeader(name: "Citra"))
    }

    // MARK: Picking

    @Test func OnlineMembersCanBePicked() {
        var state = State(leaderSecondsAgo: 300)
        state.participants.append(Fixtures.Car(id: UUID(), name: "Dewi", lastSeenSecondsAgo: 300))

        let candidates = TripMapNotices.LeaderCandidates(in: state, at: Fixtures.now)

        #expect(candidates.map(\.displayName) == ["Budi", "Citra"])
    }

    @Test(arguments: [
        (seconds: 299.0, includesCitra: false, expected: false),
        (300, false, true),
        (300, true, false)
    ])
    func TheOnlyMemberLeftBecomesLeaderAfterFiveMinutes(seconds: Double, includesCitra: Bool, expected: Bool) {
        let state = State(leaderSecondsAgo: seconds, includesCitra: includesCitra)

        #expect(TripMapNotices.ShouldTakeOver(state, me: Fixtures.budiID, at: Fixtures.now) == expected)
    }

    @Test func TheOfflineLeaderDoesNotTakeOverFromThemselves() {
        let state = State(leaderSecondsAgo: 300, includesCitra: false)

        #expect(TripMapNotices.ShouldTakeOver(state, me: Fixtures.agusID, at: Fixtures.now) == false)
    }
}
