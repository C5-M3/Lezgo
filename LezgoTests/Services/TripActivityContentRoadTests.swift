//
//  TripActivityContentRoadTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The robots on the Live Activity's road, which covers only the current leg (ADR 0027).
@MainActor
struct TripActivityContentRoadTests {
    private typealias Fixtures = TripMapFixtures
    private typealias Sample = TripActivityFixtures

    @Test func RobotsSitAlongTheCurrentLeg() throws {
        let state = TripActivityContent.State(Sample.Input())
        let agus = try #require(state.robots.first { $0.id == Fixtures.agusID })
        let budi = try #require(state.robots.first { $0.id == Fixtures.budiID })
        let citra = try #require(state.robots.first { $0.id == Fixtures.citraID })
        #expect(budi.progress == 0)
        #expect(agus.progress > 0.95)
        #expect(citra.progress > 0.4 && citra.progress < 0.6)
        #expect(budi.isMe && budi.color == .blue)
        #expect(agus.color == .yellow)
    }

    @Test func CarsBeforeTheLegStayAtItsStart() throws {
        let state = TripActivityContent.State(Sample.Input(currentWaypointIndex: 2))
        let budi = try #require(state.robots.first { $0.id == Fixtures.budiID })
        #expect(budi.progress == 0)
    }

    @Test func CarsPastTheNextStopStayAtTheFlag() throws {
        let past = Coordinate(latitude: -7.2893, longitude: 112.60)
        let budi = Sample.Pin(Fixtures.budiID, "Budi", at: past, color: .blue, isMe: true)
        let state = TripActivityContent.State(Sample.Input(cars: [budi]))
        let robot = try #require(state.robots.first)
        #expect(robot.progress == 1)
    }

    @Test func YellowLineReachesTheCarFurthestAhead() throws {
        let state = TripActivityContent.State(Sample.Input())
        let furthest = try #require(state.robots.map(\.progress).max())
        #expect(state.reached == furthest)
    }

    @Test func OfflineCarsShowTheirScreenOff() throws {
        var citra = Sample.citra
        citra.isOffline = true
        let state = TripActivityContent.State(Sample.Input(cars: [Sample.agus, Sample.budi, citra]))
        #expect(state.robots.first { $0.id == Fixtures.citraID }?.isOnline == false)
        #expect(state.robots.first { $0.id == Fixtures.budiID }?.isOnline == true)
    }

    @Test func ArrivedCarsWaitAtTheFlag() throws {
        let progress = TripMapArrivalProgress(robots: [], arrivedCount: 1, totalCount: 3)
        var budi = Sample.budi
        budi.coordinate = Fixtures.destination.coordinate
        let state = TripActivityContent.State(
            Sample.Input(
                cars: [Sample.agus, budi, Sample.citra],
                currentWaypointIndex: 3,
                arrivalCard: .waitingForEveryone,
                arrivalProgress: progress
            )
        )
        #expect(state.robots.first { $0.isMe }?.progress == 1)
    }

    @Test func ManyCarsKeepMeAndTheLeaderOnTheRoad() {
        let others = (1...12).map {
            Sample.Pin(UUID(), "Car \($0)", at: Sample.quarterWay, color: .green)
        }
        let state = TripActivityContent.State(Sample.Input(cars: others + [Sample.budi, Sample.agus]))
        #expect(state.robots.count == TripActivityAttributes.maxRobots)
        #expect(state.robots.contains { $0.isMe })
        #expect(state.robots.contains { $0.id == Fixtures.agusID })
    }

    @Test func StateFitsActivityKitsSizeLimit() throws {
        let cars = (0..<20).map {
            Sample.Pin(UUID(), String(repeating: "Bartholomew \($0) ", count: 4), at: Sample.quarterWay, color: .green)
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
