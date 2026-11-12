//
//  TripActivityContentTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

@MainActor
struct TripActivityContentTests {
    private typealias Fixtures = TripMapFixtures
    private static let route = [
        Fixtures.startPoint.coordinate, Fixtures.checkpoint.coordinate, Fixtures.destination.coordinate
    ]

    private static func Pin(
        _ id: UUID,
        _ name: String,
        at coordinate: Coordinate,
        color: TripMapCarPin.CarColor,
        isLeader: Bool = false,
        isMe: Bool = false,
        isOffline: Bool = false,
        isAlerting: Bool = false
    ) -> TripMapCarPin {
        TripMapCarPin(
            id: id,
            displayName: name,
            coordinate: coordinate,
            motionState: .driving,
            isLeader: isLeader,
            isMe: isMe,
            isOffline: isOffline,
            isAlerting: isAlerting,
            carColor: color
        )
    }

    private static let agus = Pin(
        Fixtures.agusID, "Agus", at: Fixtures.checkpoint.coordinate, color: .yellow, isLeader: true
    )
    private static let budi = Pin(Fixtures.budiID, "Budi", at: Fixtures.startPoint.coordinate, color: .blue, isMe: true)
    private static let citra = Pin(Fixtures.citraID, "Citra", at: Fixtures.startPoint.coordinate, color: .pink)

    private static func Input(
        guidance: TripMapGuidance? = Fixtures.Guidance(minutesLeft: 80),
        isRerouting: Bool = false,
        cars: [TripMapCarPin] = [agus, budi, citra],
        upcomingWaypoints: [Waypoint] = [Fixtures.checkpoint, Fixtures.destination],
        alertBanner: TripMapAlerts.Banner? = nil,
        arrivalCard: TripMapViewModel.ArrivalCard? = nil,
        arrivalProgress: TripMapArrivalProgress? = nil,
        isMuted: Bool = false
    ) -> TripActivityContent.Input {
        TripActivityContent.Input(
            guidance: guidance,
            isRerouting: isRerouting,
            cars: cars,
            route: route,
            upcomingWaypoints: upcomingWaypoints,
            alertBanner: alertBanner,
            arrivalCard: arrivalCard,
            arrivalProgress: arrivalProgress,
            isMuted: isMuted,
            now: Fixtures.now
        )
    }

    @Test func TitleNamesTheDestination() {
        #expect(TripActivityContent.Attributes(destinationName: "Pakuwon mall").title == "To Pakuwon mall")
    }

    @Test func DrivingShowsTheNextTurnAndTimeLeft() throws {
        let state = TripActivityContent.State(Self.Input())
        #expect(state.stage == .driving)
        let turn = try #require(state.turn)
        #expect(turn.symbolName == "arrow.turn.up.right")
        #expect(turn.distanceText == "200 m")
        #expect(turn.instruction == "Turn right")
        #expect(state.timeLeftText == "1 hr, 20 min")
    }

    @Test func CompactIslandGetsAShortTime() {
        #expect(TripActivityContent.State(Self.Input()).shortTimeLeftText == "1:20")
        let soon = TripActivityContent.State(Self.Input(guidance: Fixtures.Guidance(minutesLeft: 9)))
        #expect(soon.shortTimeLeftText == "0:09")
    }

    @Test func DetailShowsDistanceLeftAndArrivalTime() throws {
        var guidance = Fixtures.Guidance(minutesLeft: 80)
        guidance.distanceLeft = Measurement(value: 64, unit: .kilometers)
        let state = TripActivityContent.State(Self.Input(guidance: guidance))
        let arrival = Fixtures.now.addingTimeInterval(80 * 60).formatted(date: .omitted, time: .shortened)
        #expect(state.detailText == "64 km · Arrive \(arrival)")
    }

    @Test func DetailWithoutDistanceLeftShowsOnlyTheArrivalTime() {
        let state = TripActivityContent.State(Self.Input())
        let arrival = Fixtures.now.addingTimeInterval(80 * 60).formatted(date: .omitted, time: .shortened)
        #expect(state.detailText == "Arrive \(arrival)")
    }

    @Test func NoGuidanceYetIsLoading() {
        let state = TripActivityContent.State(Self.Input(guidance: nil))
        #expect(state.stage == .loading)
        #expect(state.turn == nil)
        #expect(state.timeLeftText == nil)
    }

    @Test func ReroutingHidesTheTurn() {
        let state = TripActivityContent.State(Self.Input(isRerouting: true))
        #expect(state.stage == .rerouting)
        #expect(state.turn == nil)
    }

    @Test func NextStopIsTheFirstCheckpointAhead() {
        let state = TripActivityContent.State(Self.Input())
        #expect(state.nextStopText == "Next stop: Ciputra World")
    }

    @Test func OnlyTheDestinationLeftHasNoNextStop() {
        let state = TripActivityContent.State(Self.Input(upcomingWaypoints: [Fixtures.destination]))
        #expect(state.nextStopText == nil)
    }

    @Test func MemberFollowsTheLeader() {
        let state = TripActivityContent.State(Self.Input())
        #expect(state.isLeader == false)
        #expect(state.groupText == "Following Agus")
        #expect(state.isGroupWarning == false)
        #expect(state.myColor == .blue)
    }

    @Test func LeaderCountsCarsOnRoute() {
        var leader = Self.agus
        leader.isMe = true
        var budi = Self.budi
        budi.isMe = false
        var citra = Self.citra
        citra.isAlerting = true
        let state = TripActivityContent.State(Self.Input(cars: [leader, budi, citra]))
        #expect(state.isLeader)
        #expect(state.groupText == "2/3 cars on route")
        #expect(state.isGroupWarning)
    }

    @Test func OfflineCarsAreNotOnRoute() {
        var leader = Self.agus
        leader.isMe = true
        var budi = Self.budi
        budi.isMe = false
        budi.isOffline = true
        let state = TripActivityContent.State(Self.Input(cars: [leader, budi]))
        #expect(state.groupText == "1/2 cars on route")
    }

    @Test func RobotsSitAlongTheRoute() throws {
        let state = TripActivityContent.State(Self.Input())
        let agus = try #require(state.robots.first { $0.id == Fixtures.agusID })
        let budi = try #require(state.robots.first { $0.id == Fixtures.budiID })
        #expect(budi.progress == 0)
        #expect(agus.progress > 0.3 && agus.progress < 0.7)
        #expect(agus.isLeader && agus.color == .yellow)
        #expect(budi.isMe && budi.color == .blue)
    }

    @Test func RobotsPastTheEndStayOnTheRoad() throws {
        let past = Coordinate(latitude: -7.2893, longitude: 112.60)
        let budi = Self.Pin(Fixtures.budiID, "Budi", at: past, color: .blue)
        let state = TripActivityContent.State(Self.Input(cars: [budi]))
        let robot = try #require(state.robots.first)
        #expect(robot.progress <= 1)
    }

    @Test func ManyCarsKeepMeAndTheLeaderOnTheRoad() {
        let others = (0..<12).map { Self.Pin(UUID(), "Car \($0)", at: Fixtures.startPoint.coordinate, color: .green) }
        let state = TripActivityContent.State(Self.Input(cars: others + [Self.budi, Self.agus]))
        #expect(state.robots.count == TripActivityAttributes.maxRobots)
        #expect(state.robots.contains { $0.isMe })
        #expect(state.robots.contains { $0.isLeader })
    }

    @Test func AnotherCarsAlertUsesItsRobotAndTheMapText() throws {
        var citra = Self.citra
        citra.isAlerting = true
        let banner = TripMapAlerts.Banner.otherCar(id: Fixtures.citraID, name: "Citra", alert: .offRoute)
        let state = TripActivityContent.State(Self.Input(cars: [Self.agus, Self.budi, citra], alertBanner: banner))
        let alert = try #require(state.alert)
        #expect(alert.text == "Citra has gone out of route")
        #expect(alert.color == .pink)
        #expect(alert.carName == "Citra")
        #expect(state.robots.first { $0.id == Fixtures.citraID }?.isAlerting == true)
    }

    @Test func MyOwnAlertUsesMyRobot() throws {
        let state = TripActivityContent.State(Self.Input(alertBanner: .mine(.offRoute)))
        let alert = try #require(state.alert)
        #expect(alert.color == .blue)
        #expect(alert.carName == "You")
    }

    @Test func ArrivedShowsTheTitleAndCount() throws {
        let progress = TripMapArrivalProgress(robots: [], arrivedCount: 3, totalCount: 4)
        let state = TripActivityContent.State(
            Self.Input(arrivalCard: .waitingForEveryone, arrivalProgress: progress)
        )
        #expect(state.stage == .arrived)
        let arrival = try #require(state.arrival)
        #expect(arrival.title == "You have arrived")
        #expect(arrival.countText == "3/4")
        #expect(state.turn == nil)
    }

    @Test func MuteLabelFollowsTheMuteButton() {
        #expect(TripActivityContent.State(Self.Input(isMuted: false)).muteLabel == "Mute")
        let muted = TripActivityContent.State(Self.Input(isMuted: true))
        #expect(muted.isMuted)
        #expect(muted.muteLabel == "Unmute")
    }

    @Test func VeryLongNamesAreKeptWhole() {
        let name = "Rest area KM 57 Jalan Tol Jagorawi arah Puncak Bogor Jawa Barat"
        let stop = Waypoint(
            id: UUID(), tripID: Fixtures.tripID, orderIndex: 1, kind: .checkpoint, name: name,
            coordinate: Fixtures.checkpoint.coordinate
        )
        let state = TripActivityContent.State(Self.Input(upcomingWaypoints: [stop, Fixtures.destination]))
        #expect(state.nextStopText == "Next stop: \(name)")
    }

    @Test func StateFitsActivityKitsSizeLimit() throws {
        let cars = (0..<20).map {
            let name = String(repeating: "Bartholomew \($0) ", count: 4)
            return Self.Pin(UUID(), name, at: Fixtures.startPoint.coordinate, color: .green)
        }
        let state = TripActivityContent.State(Self.Input(cars: cars + [Self.budi, Self.agus]))
        let size = try JSONEncoder().encode(state).count
        #expect(size < 4_096)
    }
}
