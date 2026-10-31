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

    @Test func DistanceLeftIsTheRestOfTheRoad() async throws {
        let setup = Setup()

        let guidance = try await setup.navigator.Guidance(
            from: Self.Offset(Self.start, north: 500),
            along: TripMapFixtures.State()
        )

        let metresLeft = try #require(guidance.distanceLeft).converted(to: .meters).value
        #expect(abs(metresLeft - 1_500) < 10)
    }

    @Test func SmallWiggleAtTheCornerDoesNotHideTheTurn() async throws {
        // Real roads have small kinks: here the road edges east 5 m just before a right bend to the north-east.
        // Measured from that kink alone the bend looks straight; measured over 30 m it is a right turn.
        let kink = Self.Offset(Self.corner, north: -3, east: -5)
        let northEast = Self.Offset(Self.corner, north: 700, east: 700)
        let setup = Setup([.success(DrivingDirections(
            steps: [
                DrivingDirections.Step(instruction: "", path: [Self.start, kink, Self.corner]),
                DrivingDirections.Step(instruction: "", path: [Self.corner, northEast])
            ],
            expectedTravelTime: 240
        ))])

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(guidance.direction == .right)
    }

    @Test(arguments: [
        ("At the roundabout, turn left onto Jalan Citra Raya Niaga", TripMapGuidance.TurnDirection.roundabout),
        ("Di bundaran, ambil jalan keluar ke-2", .roundabout),
        ("Make a U-turn", .uTurn),
        ("Putar balik", .uTurn),
        ("Turn left onto Jalan Darmo", .left),
        ("Keep left", .left),
        ("Belok kiri ke Jalan Darmo", .left),
        ("Belok kanan ke Jalan Darmo", .right)
    ])
    func InstructionDecidesTheArrowOverTheShapeOfTheRoad(
        instruction: String,
        direction: TripMapGuidance.TurnDirection
    ) async throws {
        // The road bends right; MapKit's own words still win, because it knows the junction.
        let setup = Setup([.success(DrivingDirections(
            steps: [
                DrivingDirections.Step(instruction: "", path: [Self.start, Self.corner]),
                DrivingDirections.Step(instruction: instruction, path: [Self.corner, Self.end])
            ],
            expectedTravelTime: 240
        ))])

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(guidance.direction == direction)
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
