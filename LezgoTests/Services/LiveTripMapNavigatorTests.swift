//
//  LiveTripMapNavigatorTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 30/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The road in these tests: 1 km north from `start` to `corner`, then 1 km east (a right turn) to `end`.
struct LiveTripMapNavigatorTests {
    private static let start = Coordinate(latitude: -7.2700, longitude: 112.7300)
    private static let corner = Offset(start, north: 1_000)
    private static let end = Offset(corner, east: 1_000)

    private static let rightTurn = DrivingDirections(
        steps: [
            DrivingDirections.Step(instruction: "", path: [start, corner]),
            DrivingDirections.Step(instruction: "Turn right onto Jalan Darmo", path: [corner, end]),
            DrivingDirections.Step(instruction: "Arrive at the destination", path: [end])
        ],
        expectedTravelTime: 240
    )

    /// A `TripMapNavigator` with a clock the test moves forward.
    private final class Setup {
        var now = TripMapFixtures.now
        let directions: MockDrivingDirectionsService
        private(set) lazy var navigator = LiveTripMapNavigator(directionsService: directions, clock: { self.now })

        init(_ results: [Result<DrivingDirections, MockDrivingDirectionsService.NoRoute>] = [.success(rightTurn)]) {
            directions = MockDrivingDirectionsService(results: results)
        }
    }

    @Test func FirstGuidanceAsksForDirectionsThroughTheWaypointsAhead() async throws {
        let setup = Setup()

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(setup.directions.requestedPoints == [[
            Self.start, TripMapFixtures.checkpoint.coordinate, TripMapFixtures.destination.coordinate
        ]])
        #expect(guidance.direction == .right)
        #expect(guidance.instruction == "Turn right onto Jalan Darmo")
        #expect(abs(guidance.distanceToTurn.converted(to: .meters).value - 1_000) < 10)
        #expect(guidance.timeLeft == .seconds(240))
    }

    @Test func CarStillOnThePathReusesTheDirections() async throws {
        let setup = Setup()
        _ = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())
        setup.now += 5

        let guidance = try await setup.navigator.Guidance(
            from: Self.Offset(Self.start, north: 500),
            along: TripMapFixtures.State()
        )

        #expect(setup.directions.requestedPoints.count == 1)
        #expect(abs(guidance.distanceToTurn.converted(to: .meters).value - 500) < 10)
        #expect(abs(guidance.timeLeft / .seconds(1) - 180) < 2)
    }

    @Test func AfterTheLastTurnTheGuidanceLeadsToTheDestination() async throws {
        let setup = Setup()
        _ = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        let guidance = try await setup.navigator.Guidance(
            from: Self.Offset(Self.corner, east: 500),
            along: TripMapFixtures.State()
        )

        #expect(guidance.direction == .straight)
        #expect(guidance.instruction == "Arrive at the destination")
        #expect(abs(guidance.distanceToTurn.converted(to: .meters).value - 500) < 10)
    }

    @Test func CarOffThePathAsksAgain() async throws {
        let setup = Setup()
        _ = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        _ = try await setup.navigator.Guidance(
            from: Self.Offset(Self.start, north: 500, east: 200),
            along: TripMapFixtures.State()
        )

        #expect(setup.directions.requestedPoints.count == 2)
    }

    @Test func NewRouteVersionAsksAgain() async throws {
        let setup = Setup()
        _ = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())
        var rerouted = TripMapFixtures.State()
        rerouted.trip.routeVersion += 1

        _ = try await setup.navigator.Guidance(from: Self.start, along: rerouted)

        #expect(setup.directions.requestedPoints.count == 2)
    }

    @Test func PassedCheckpointAsksAgainForTheRestOfTheWay() async throws {
        let setup = Setup()
        _ = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        _ = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State(currentWaypointIndex: 2))

        #expect(setup.directions.requestedPoints.last == [Self.start, TripMapFixtures.destination.coordinate])
    }

    @Test func DirectionsOlderThanAMinuteAreAskedAgain() async throws {
        let setup = Setup()
        _ = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())
        setup.now += 61

        _ = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(setup.directions.requestedPoints.count == 2)
    }

    @Test func FailedRequestThrowsAndWaitsBeforeAskingAgain() async throws {
        let setup = Setup([.failure(MockDrivingDirectionsService.NoRoute()), .success(Self.rightTurn)])

        await #expect(throws: (any Error).self) {
            try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())
        }
        setup.now += 5
        await #expect(throws: (any Error).self) {
            try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())
        }
        #expect(setup.directions.requestedPoints.count == 1)

        setup.now += 6
        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())
        #expect(guidance.direction == .right)
    }

    @Test func BendToTheWestIsALeftTurn() async throws {
        let west = Self.Offset(Self.corner, east: -1_000)
        let setup = Setup([.success(DrivingDirections(
            steps: [
                DrivingDirections.Step(instruction: "", path: [Self.start, Self.corner]),
                DrivingDirections.Step(instruction: "Turn left", path: [Self.corner, west])
            ],
            expectedTravelTime: 240
        ))])

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(guidance.direction == .left)
    }

    @Test func DirectionsWithoutStepsThrow() async {
        let setup = Setup([.success(DrivingDirections(steps: [], expectedTravelTime: 0))])

        await #expect(throws: (any Error).self) {
            try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())
        }
    }

    /// `coordinate` moved `north` and `east` metres.
    private static func Offset(_ coordinate: Coordinate, north: Double = 0, east: Double = 0) -> Coordinate {
        let metresPerDegree = 111_320.0
        return Coordinate(
            latitude: coordinate.latitude + north / metresPerDegree,
            longitude: coordinate.longitude + east / (metresPerDegree * cos(coordinate.latitude * .pi / 180))
        )
    }
}
