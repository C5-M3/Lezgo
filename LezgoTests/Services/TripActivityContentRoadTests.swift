//
//  TripActivityContentRoadTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The robots and stops on the Live Activity's convoy road (ADR 0027).
@MainActor
struct TripActivityContentRoadTests {
    private typealias Fixtures = TripMapFixtures
    private typealias Sample = TripActivityFixtures

    @Test func EveryCheckpointIsAStopOnTheRoad() throws {
        let state = TripActivityContent.State(Sample.Input(currentWaypointIndex: 2))
        #expect(state.stops.map(\.number) == [1, 2])
        let first = try #require(state.stops.first)
        let second = try #require(state.stops.last)
        #expect(first.isVisited)
        #expect(second.isVisited == false)
        #expect(first.progress > 0.35 && first.progress < 0.6)
        #expect(second.progress > first.progress && second.progress < 1)
    }

    @Test func TripWithoutCheckpointsHasNoStops() {
        let state = TripActivityContent.State(Sample.Input(waypoints: [Fixtures.startPoint, Fixtures.destination]))
        #expect(state.stops.isEmpty)
        #expect(state.headline == "To Pakuwon mall")
    }

    @Test func RobotsSitAlongTheRoute() throws {
        let state = TripActivityContent.State(Sample.Input())
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
        let budi = Sample.Pin(Fixtures.budiID, "Budi", at: past, color: .blue)
        let state = TripActivityContent.State(Sample.Input(cars: [budi]))
        let robot = try #require(state.robots.first)
        #expect(robot.progress <= 1)
    }

    @Test func CarsCloseTogetherShareOneRobotThatShowsMeFirst() throws {
        let dani = Sample.Pin(UUID(), "Dani", at: Fixtures.startPoint.coordinate, color: .green)
        let state = TripActivityContent.State(Sample.Input(cars: [dani, Sample.budi, Sample.agus]))
        #expect(state.robots.count == 2)
        let group = try #require(state.robots.first { $0.progress == 0 })
        #expect(group.isMe)
        #expect(group.groupCount == 2)
    }

    /// The driver must see which car the alert is about, even when it is right next to their own car.
    @Test func AnAlertingCarAlwaysHasItsOwnRobot() throws {
        var citra = Sample.citra
        citra.coordinate = Fixtures.startPoint.coordinate
        citra.isAlerting = true
        let dani = Sample.Pin(UUID(), "Dani", at: Fixtures.startPoint.coordinate, color: .green)
        let state = TripActivityContent.State(Sample.Input(cars: [dani, citra, Sample.budi, Sample.agus]))
        let alerting = try #require(state.robots.first { $0.id == Fixtures.citraID })
        #expect(alerting.isAlerting)
        #expect(alerting.groupCount == 1)
        let mine = try #require(state.robots.first { $0.isMe })
        #expect(mine.groupCount == 2)
    }

    @Test func ManyCarsKeepMeAndTheLeaderOnTheRoad() {
        let others = (1...12).map { index in
            let fraction = Double(index) / 13
            let point = Coordinate(
                latitude: Fixtures.checkpoint.coordinate.latitude,
                longitude: 112.7190 + (112.6766 - 112.7190) * fraction
            )
            return Sample.Pin(UUID(), "Car \(index)", at: point, color: .green)
        }
        let state = TripActivityContent.State(Sample.Input(cars: others + [Sample.budi, Sample.agus]))
        #expect(state.robots.count <= TripActivityAttributes.maxRobots)
        #expect(state.robots.contains { $0.isMe })
        #expect(state.robots.contains { $0.isLeader })
    }

    @Test func StateFitsActivityKitsSizeLimit() throws {
        let cars = (0..<20).map {
            let name = String(repeating: "Bartholomew \($0) ", count: 4)
            return Sample.Pin(UUID(), name, at: Fixtures.startPoint.coordinate, color: .green)
        }
        let stops = (1...10).map {
            Waypoint(
                id: UUID(), tripID: Fixtures.tripID, orderIndex: $0, kind: .checkpoint,
                name: String(repeating: "Long stop name ", count: 6), coordinate: Fixtures.checkpoint.coordinate
            )
        }
        let input = Sample.Input(cars: cars + [Sample.budi, Sample.agus], waypoints: [Fixtures.startPoint] + stops)
        let size = try JSONEncoder().encode(TripActivityContent.State(input)).count
        #expect(size < 4_096)
    }
}
