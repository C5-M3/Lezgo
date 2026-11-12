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
    /// A second checkpoint half way along the second leg, about three quarters along the route.
    private static let secondCheckpoint = Waypoint(
        id: UUID(), tripID: Fixtures.tripID, orderIndex: 2, kind: .checkpoint, name: "Rest area KM 57",
        coordinate: Coordinate(latitude: -7.2908, longitude: 112.6978)
    )
    private static var lastStop: Waypoint {
        var destination = Fixtures.destination
        destination.orderIndex = 3
        return destination
    }
    private static let waypoints = [Fixtures.startPoint, Fixtures.checkpoint, secondCheckpoint, lastStop]
    /// Half way along the first leg, about a quarter along the route.
    private static let quarterWay = Coordinate(latitude: -7.27715, longitude: 112.7285)

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
    private static let citra = Pin(Fixtures.citraID, "Citra", at: quarterWay, color: .pink)

    private static func Input(
        guidance: TripMapGuidance? = Fixtures.Guidance(minutesLeft: 80),
        isRerouting: Bool = false,
        cars: [TripMapCarPin] = [agus, budi, citra],
        waypoints: [Waypoint] = waypoints,
        currentWaypointIndex: Int = 1,
        alertBanner: TripMapAlerts.Banner? = nil,
        arrivalCard: TripMapViewModel.ArrivalCard? = nil,
        arrivalProgress: TripMapArrivalProgress? = nil,
        isMuted: Bool = false
    ) -> TripActivityContent.Input {
        TripActivityContent.Input(
            destinationName: "Pakuwon mall",
            guidance: guidance,
            isRerouting: isRerouting,
            cars: cars,
            route: route,
            waypoints: waypoints,
            currentWaypointIndex: currentWaypointIndex,
            alertBanner: alertBanner,
            arrivalCard: arrivalCard,
            arrivalProgress: arrivalProgress,
            isMuted: isMuted,
            now: Fixtures.now
        )
    }

    private static func ArrivalClock(minutesLeft: Int) -> String {
        Fixtures.now.addingTimeInterval(TimeInterval(minutesLeft * 60)).formatted(date: .omitted, time: .shortened)
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
        #expect(state.arrivalTimeText == Self.ArrivalClock(minutesLeft: 80))
    }

    @Test func CompactIslandGetsAShortTime() {
        #expect(TripActivityContent.State(Self.Input()).shortTimeLeftText == "1:20")
        let soon = TripActivityContent.State(Self.Input(guidance: Fixtures.Guidance(minutesLeft: 33)))
        #expect(soon.shortTimeLeftText == "33 min")
    }

    @Test func DetailShowsDistanceLeftAndArrivalTime() {
        var guidance = Fixtures.Guidance(minutesLeft: 80)
        guidance.distanceLeft = Measurement(value: 64, unit: .kilometers)
        let state = TripActivityContent.State(Self.Input(guidance: guidance))
        #expect(state.detailText == "64 km · Arrive \(Self.ArrivalClock(minutesLeft: 80))")
    }

    @Test func DetailWithoutDistanceLeftShowsOnlyTheArrivalTime() {
        let state = TripActivityContent.State(Self.Input())
        #expect(state.detailText == "Arrive \(Self.ArrivalClock(minutesLeft: 80))")
    }

    @Test func NoGuidanceYetIsLoading() {
        let state = TripActivityContent.State(Self.Input(guidance: nil))
        #expect(state.stage == .loading)
        #expect(state.turn == nil)
        #expect(state.timeLeftText == nil)
    }

    @Test func ReroutingHidesTheTurnAndSaysSo() {
        let state = TripActivityContent.State(Self.Input(isRerouting: true))
        #expect(state.stage == .rerouting)
        #expect(state.turn == nil)
        #expect(state.statusText == "Rerouting…")
    }

    @Test func HeadlineNamesTheNextStop() {
        #expect(TripActivityContent.State(Self.Input()).headline == "Next stop · Ciputra World")
        let later = TripActivityContent.State(Self.Input(currentWaypointIndex: 2))
        #expect(later.headline == "Next stop · Rest area KM 57")
    }

    @Test func HeadlineNamesTheDestinationOnTheLastLeg() {
        let state = TripActivityContent.State(Self.Input(currentWaypointIndex: 3))
        #expect(state.headline == "To Pakuwon mall")
    }

    @Test func EveryCheckpointIsAStopOnTheRoad() throws {
        let state = TripActivityContent.State(Self.Input(currentWaypointIndex: 2))
        #expect(state.stops.map(\.number) == [1, 2])
        let first = try #require(state.stops.first)
        let second = try #require(state.stops.last)
        #expect(first.isVisited)
        #expect(second.isVisited == false)
        #expect(first.progress > 0.35 && first.progress < 0.6)
        #expect(second.progress > first.progress && second.progress < 1)
    }

    @Test func TripWithoutCheckpointsHasNoStops() {
        let state = TripActivityContent.State(Self.Input(waypoints: [Fixtures.startPoint, Fixtures.destination]))
        #expect(state.stops.isEmpty)
        #expect(state.headline == "To Pakuwon mall")
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
        #expect(agus.progress > 0.35 && agus.progress < 0.6)
        #expect(agus.isLeader && agus.color == .yellow)
        #expect(budi.isMe && budi.color == .blue)
        #expect(state.robots.allSatisfy { $0.groupCount == 1 })
    }

    @Test func RobotsPastTheEndStayOnTheRoad() throws {
        let past = Coordinate(latitude: -7.2893, longitude: 112.60)
        let budi = Self.Pin(Fixtures.budiID, "Budi", at: past, color: .blue)
        let state = TripActivityContent.State(Self.Input(cars: [budi]))
        let robot = try #require(state.robots.first)
        #expect(robot.progress <= 1)
    }

    @Test func CarsCloseTogetherShareOneRobotThatShowsMeFirst() throws {
        let dani = Self.Pin(UUID(), "Dani", at: Fixtures.startPoint.coordinate, color: .green)
        let state = TripActivityContent.State(Self.Input(cars: [dani, Self.budi, Self.agus]))
        #expect(state.robots.count == 2)
        let group = try #require(state.robots.first { $0.progress == 0 })
        #expect(group.isMe)
        #expect(group.groupCount == 2)
    }

    @Test func AnAlertingCarIsNotHiddenInAGroup() throws {
        var citra = Self.citra
        citra.isAlerting = true
        let dani = Self.Pin(UUID(), "Dani", at: Self.quarterWay, color: .green)
        let state = TripActivityContent.State(Self.Input(cars: [dani, citra, Self.budi, Self.agus]))
        let group = try #require(state.robots.first { $0.groupCount == 2 })
        #expect(group.id == Fixtures.citraID)
        #expect(group.isAlerting)
    }

    @Test func ManyCarsKeepMeAndTheLeaderOnTheRoad() {
        let others = (1...12).map { index in
            let fraction = Double(index) / 13
            let point = Coordinate(
                latitude: Fixtures.checkpoint.coordinate.latitude,
                longitude: 112.7190 + (112.6766 - 112.7190) * fraction
            )
            return Self.Pin(UUID(), "Car \(index)", at: point, color: .green)
        }
        let state = TripActivityContent.State(Self.Input(cars: others + [Self.budi, Self.agus]))
        #expect(state.robots.count <= TripActivityAttributes.maxRobots)
        #expect(state.robots.contains { $0.isMe })
        #expect(state.robots.contains { $0.isLeader })
    }

    @Test func AnotherCarsAlertUsesItsRobotTextAndDistance() throws {
        var citra = Self.citra
        citra.isAlerting = true
        let banner = TripMapAlerts.Banner.otherCar(id: Fixtures.citraID, name: "Citra", alert: .offRoute)
        let state = TripActivityContent.State(Self.Input(cars: [Self.agus, Self.budi, citra], alertBanner: banner))
        let alert = try #require(state.alert)
        #expect(alert.text == "Citra has gone out of route")
        #expect(alert.shortText == "Off route")
        #expect(alert.color == .pink)
        #expect(alert.carName == "Citra")
        #expect(alert.detail?.hasSuffix("ahead of you") == true)
        #expect(state.robots.first { $0.id == Fixtures.citraID }?.isAlerting == true)
    }

    @Test func StoppedCarBehindTheLeaderSaysHowFarBehind() throws {
        var leader = Self.agus
        leader.isMe = true
        var budi = Self.budi
        budi.isMe = false
        let banner = TripMapAlerts.Banner.carStopped(id: Fixtures.citraID, name: "Citra")
        let state = TripActivityContent.State(Self.Input(cars: [leader, budi, Self.citra], alertBanner: banner))
        let alert = try #require(state.alert)
        #expect(alert.shortText == "Stopped")
        #expect(alert.detail?.hasSuffix("behind you") == true)
    }

    @Test func MyOwnAlertUsesMyRobot() throws {
        let state = TripActivityContent.State(Self.Input(alertBanner: .mine(.offRoute)))
        let alert = try #require(state.alert)
        #expect(alert.color == .blue)
        #expect(alert.carName == "You")
        #expect(alert.shortText == "Off route")
        #expect(alert.detail == nil)
    }

    @Test func ArrivedShowsTheTitleCountAndWhatIsNext() throws {
        let progress = TripMapArrivalProgress(robots: [], arrivedCount: 3, totalCount: 4)
        let state = TripActivityContent.State(
            Self.Input(arrivalCard: .waitingForEveryone, arrivalProgress: progress)
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
        #expect(TripActivityContent.State(Self.Input(isMuted: false)).muteLabel == "Mute")
        let muted = TripActivityContent.State(Self.Input(isMuted: true))
        #expect(muted.isMuted)
        #expect(muted.muteLabel == "Unmute")
    }

    @Test func VeryLongStopNamesAreKeptWhole() {
        let name = "Rest area KM 57 Jalan Tol Jagorawi arah Puncak Bogor Jawa Barat"
        var stop = Fixtures.checkpoint
        stop.name = name
        let state = TripActivityContent.State(Self.Input(waypoints: [Fixtures.startPoint, stop, Self.lastStop]))
        #expect(state.headline == "Next stop · \(name)")
    }

    @Test func StateFitsActivityKitsSizeLimit() throws {
        let cars = (0..<20).map {
            let name = String(repeating: "Bartholomew \($0) ", count: 4)
            return Self.Pin(UUID(), name, at: Fixtures.startPoint.coordinate, color: .green)
        }
        let stops = (1...10).map {
            Waypoint(
                id: UUID(), tripID: Fixtures.tripID, orderIndex: $0, kind: .checkpoint,
                name: String(repeating: "Long stop name ", count: 6), coordinate: Fixtures.checkpoint.coordinate
            )
        }
        let input = Self.Input(cars: cars + [Self.budi, Self.agus], waypoints: [Fixtures.startPoint] + stops)
        let size = try JSONEncoder().encode(TripActivityContent.State(input)).count
        #expect(size < 4_096)
    }
}
