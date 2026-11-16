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
///
/// The steps have MapKit's real shape: the first step is only the start point, and every other step's line runs from
/// the previous maneuver up to its own, so a step's maneuver sits at the end of its line (checked against real routes
/// in Jakarta and Surabaya, #331).
struct LiveTripMapNavigatorTests {
    private static let start = Coordinate(latitude: -7.2700, longitude: 112.7300)
    private static let corner = Offset(start, north: 1_000)
    private static let end = Offset(corner, east: 1_000)

    private static let rightTurn = Directions(turning: "Turn right onto Jalan Darmo", towards: end)

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
        #expect(guidance.instruction == "The destination is on your left")
        #expect(abs(guidance.distanceToTurn.converted(to: .meters).value - 500) < 10)
    }

    @Test func StartingOffTheTurnIsAtTheEndOfItsStep() async throws {
        let setup = Setup()

        let guidance = try await setup.navigator.Guidance(
            from: Self.Offset(Self.start, north: 200),
            along: TripMapFixtures.State()
        )

        #expect(guidance.instruction == "Turn right onto Jalan Darmo")
        #expect(guidance.direction == .right)
        #expect(abs(guidance.distanceToTurn.converted(to: .meters).value - 800) < 10)
    }

    @Test(arguments: ["The destination is on your right", "Tujuan di sebelah kiri Anda", "Arrive at the destination"])
    func ArrivingShowsTheStraightArrow(instruction: String) async throws {
        // The last step names the side of the road the stop is on; that is not a turn.
        let setup = Setup([.success(DrivingDirections(
            steps: [
                DrivingDirections.Step(instruction: "", path: [Self.start]),
                DrivingDirections.Step(instruction: instruction, path: [Self.start, Self.corner])
            ],
            expectedTravelTime: 120
        ))])

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(guidance.direction == .straight)
        #expect(guidance.instruction == instruction)
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
        let setup = Setup([.success(Self.Directions(turning: "Turn left", towards: west))])

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
                DrivingDirections.Step(instruction: "", path: [Self.start]),
                DrivingDirections.Step(instruction: "", path: [Self.start, kink, Self.corner]),
                DrivingDirections.Step(instruction: "Arrive at the destination", path: [Self.corner, northEast])
            ],
            expectedTravelTime: 240
        ))])

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(guidance.direction == .right)
    }

    /// The wording is MapKit's own, collected from real routes in English and Indonesian (#331).
    @Test(arguments: [
        ("Make a U-turn", TripMapGuidance.TurnDirection.uTurnRight),
        ("Putar balik", .uTurnRight),
        ("Turn left onto Jalan Darmo", .left),
        ("Belok kiri ke Jalan Darmo", .left),
        ("Belok kanan ke Jalan Darmo", .right),
        ("Keep left onto Jalan Darmo", .keepLeft),
        ("Tetap di kiri ke Jalan Darmo", .keepLeft),
        ("Keep right to merge onto Jalan Tol Dalam Kota", .mergeRight),
        ("Tetap di kanan untuk masuk Jalan Tol Dalam Kota", .mergeRight),
        ("Bear left onto Jalan Darmo", .slightLeft),
        ("Belok kiri sedikit ke Jalan Darmo", .slightLeft),
        ("Turn right onto Jalan Kiri", .right)
    ])
    func InstructionDecidesTheArrowOverTheShapeOfTheRoad(
        instruction: String,
        direction: TripMapGuidance.TurnDirection
    ) async throws {
        // The road bends right; MapKit's own words still win, because it knows the junction.
        let setup = Setup([.success(Self.Directions(turning: instruction, towards: Self.end))])

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(guidance.direction == direction)
    }

    @Test func InstructionWithoutASideFollowsTheRoad() async throws {
        // "Take exit 10 towards Srengseng" names no side; the road bends right.
        let setup = Setup([.success(Self.Directions(turning: "Take exit 10 towards Srengseng", towards: Self.end))])

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(guidance.direction == .right)
    }

    @Test(arguments: [
        (30.0, TripMapGuidance.TurnDirection.slightRight),
        (-30, .slightLeft),
        (90, .right),
        (-90, .left),
        (10, .straight),
        (170, .uTurnRight),
        (-170, .uTurnLeft)
    ])
    func ShapeOfTheRoadPicksTheArrow(degrees: Double, direction: TripMapGuidance.TurnDirection) async throws {
        let radians = degrees * .pi / 180
        let away = Self.Offset(Self.corner, north: 1_000 * cos(radians), east: 1_000 * sin(radians))
        let setup = Setup([.success(Self.Directions(turning: "", towards: away))])

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(guidance.direction == direction)
    }

    @Test func RoundaboutShowsTheWayOut() async throws {
        // Driving north into a roundabout and leaving it to the east is a right turn. Clockwise round the ring, the
        // road already heads east-south-east before the exit, so the bend at the exit alone would look straight on.
        let entry = Self.corner
        let ring = [
            Self.Offset(entry, north: 15, east: -15),
            Self.Offset(entry, north: 40, east: -5),
            Self.Offset(entry, north: 45, east: 20),
            Self.Offset(entry, north: 30, east: 40)
        ]
        let exit = ring[3]
        let setup = Setup([.success(DrivingDirections(
            steps: [
                DrivingDirections.Step(instruction: "", path: [Self.start]),
                DrivingDirections.Step(
                    instruction: "At the roundabout, take the second exit onto Jalan Darmo",
                    path: [Self.start, entry] + ring
                ),
                DrivingDirections.Step(
                    instruction: "The destination is on your left",
                    path: [exit, Self.Offset(exit, east: 1_000)]
                )
            ],
            expectedTravelTime: 240
        ))])

        let guidance = try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())

        #expect(guidance.instruction == "At the roundabout, take the second exit onto Jalan Darmo")
        #expect(guidance.direction == .right)
    }

    @Test func DirectionsWithoutStepsThrow() async {
        let setup = Setup([.success(DrivingDirections(steps: [], expectedTravelTime: 0))])

        await #expect(throws: (any Error).self) {
            try await setup.navigator.Guidance(from: Self.start, along: TripMapFixtures.State())
        }
    }

    /// MapKit's shape for one maneuver at `corner`: the start point, the step up to the maneuver, then the step from
    /// it to `destination`.
    private static func Directions(turning instruction: String, towards destination: Coordinate) -> DrivingDirections {
        DrivingDirections(
            steps: [
                DrivingDirections.Step(instruction: "", path: [start]),
                DrivingDirections.Step(instruction: instruction, path: [start, corner]),
                DrivingDirections.Step(instruction: "The destination is on your left", path: [corner, destination])
            ],
            expectedTravelTime: 240
        )
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
