//
//  LiveTripMapNavigator.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 30/10/26.
//

import Foundation

/// The next turn and the time left from MapKit driving directions, through the waypoints still ahead (#214).
///
/// The map asks for guidance about once a second, but MapKit allows only about 50 requests a minute. So the
/// navigator keeps the last directions and works the guidance out from them while the car stays on their road. It
/// asks MapKit again when the car is more than 50 m from that road, after a minute (for fresh traffic), or when the
/// route version or the next checkpoint changes. After a failed request it waits 10 seconds before asking again.
///
/// The map also asks for the time left of a tapped car, from another position. A few directions are kept, so that
/// lookup does not throw away the directions of this phone's car.
final class LiveTripMapNavigator: TripMapNavigator {
    struct NoDirections: Error {}

    private static let maximumDistanceFromRoad: Double = 50
    private static let maximumAge: TimeInterval = 60
    private static let waitAfterFailure: TimeInterval = 10
    private static let keptDirectionsCount = 4
    /// A turn this close behind the car counts as passed, so GPS noise at the corner does not show it again.
    private static let passedTurnTolerance: Double = 5

    private let directionsService: any DrivingDirectionsService
    private let clock: () -> Date
    private var kept: [KeptDirections] = []
    private var lastFailureAt: Date?

    init(
        directionsService: any DrivingDirectionsService = LiveDrivingDirectionsService(),
        clock: @escaping () -> Date = { .now }
    ) {
        self.directionsService = directionsService
        self.clock = clock
    }

    func Guidance(from position: Coordinate, along state: TripState) async throws -> TripMapGuidance {
        let now = clock()
        if let match = Usable(from: position, along: state, at: now) {
            return Guidance(at: match.position, on: match.directions)
        }
        if let lastFailureAt, now.timeIntervalSince(lastFailureAt) < Self.waitAfterFailure {
            throw NoDirections()
        }
        let directions = try await Fetch(from: position, along: state, at: now)
        guard let located = RoutePosition.Locate(position, on: directions.path) else { throw NoDirections() }
        return Guidance(at: located, on: directions)
    }

    // MARK: Asking MapKit

    private func Fetch(from position: Coordinate, along state: TripState, at now: Date) async throws -> KeptDirections {
        let ahead: [Coordinate] = state.waypoints
            .filter { $0.IsVisited(currentWaypointIndex: state.trip.currentWaypointIndex) == false }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(\.coordinate)
        do {
            let directions = try await directionsService.Directions(through: [position] + ahead)
            guard let fetched = KeptDirections(directions, for: state, fetchedAt: now) else { throw NoDirections() }
            lastFailureAt = nil
            kept = [fetched] + kept.prefix(Self.keptDirectionsCount - 1)
            return fetched
        } catch {
            lastFailureAt = now
            throw error
        }
    }

    /// Kept directions for the same route and checkpoint, fresh enough, whose road the car is still on.
    private func Usable(
        from position: Coordinate,
        along state: TripState,
        at now: Date
    ) -> (directions: KeptDirections, position: RoutePosition)? {
        let fresh = kept.filter { $0.IsFor(state) && now.timeIntervalSince($0.fetchedAt) < Self.maximumAge }
        for directions in fresh {
            if let located = RoutePosition.Locate(position, on: directions.path),
               located.distanceFromRoute <= Self.maximumDistanceFromRoad {
                return (directions, located)
            }
        }
        return nil
    }

    // MARK: Working out the guidance

    private func Guidance(at position: RoutePosition, on directions: KeptDirections) -> TripMapGuidance {
        let along = position.distanceAlongRoute
        let remaining = max(directions.length - along, 0)
        let timeLeft = directions.length > 0 ? directions.expectedTravelTime * remaining / directions.length : 0
        let nextTurn = directions.turns.first { $0.distanceAlongRoute > along + Self.passedTurnTolerance }
        let turnAlong = nextTurn?.distanceAlongRoute ?? directions.length
        return TripMapGuidance(
            direction: nextTurn?.direction ?? .straight,
            instruction: nextTurn?.instruction ?? directions.turns.last?.instruction ?? "",
            distanceToTurn: Measurement(value: max(turnAlong - along, 0), unit: .meters),
            timeLeft: .seconds(Int(timeLeft.rounded())),
            distanceLeft: Measurement(value: remaining, unit: .meters)
        )
    }
}

// MARK: - Kept directions

/// One answer from MapKit as one road, with every turn's place along it, kept by `LiveTripMapNavigator`.
private struct KeptDirections {
    let routeVersion: Int
    let currentWaypointIndex: Int
    let fetchedAt: Date
    let expectedTravelTime: TimeInterval
    let path: [Coordinate]
    /// Metres along `path` from start to end, measured like `RoutePosition` measures the car.
    let length: Double
    /// Every step after the first, which only says to start driving.
    let turns: [Turn]

    /// A bend sharper than this, in degrees, shows a left or right arrow.
    private static let turnThresholdDegrees = 20.0

    struct Turn {
        let instruction: String
        let direction: TripMapGuidance.TurnDirection
        let distanceAlongRoute: Double
    }

    init?(_ directions: DrivingDirections, for state: TripState, fetchedAt: Date) {
        var path: [Coordinate] = []
        var stepStarts: [Int] = []
        for step in directions.steps {
            stepStarts.append(step.path.first == path.last ? max(path.count - 1, 0) : path.count)
            path.append(contentsOf: step.path.first == path.last ? step.path.dropFirst() : step.path[...])
        }
        guard path.isEmpty == false else { return nil }
        let lengths = PathTurns.LengthsAlong(path)

        routeVersion = state.trip.routeVersion
        currentWaypointIndex = state.trip.currentWaypointIndex
        self.fetchedAt = fetchedAt
        expectedTravelTime = directions.expectedTravelTime
        self.path = path
        length = lengths.last ?? 0
        turns = zip(directions.steps, stepStarts).dropFirst().map { step, start in
            Turn(
                instruction: step.instruction,
                direction: Self.Direction(saying: step.instruction) ?? PathTurns.Direction(
                    in: path,
                    lengths: lengths,
                    at: start,
                    threshold: Self.turnThresholdDegrees
                ),
                distanceAlongRoute: lengths[start]
            )
        }
    }

    func IsFor(_ state: TripState) -> Bool {
        routeVersion == state.trip.routeVersion && currentWaypointIndex == state.trip.currentWaypointIndex
    }

    /// The arrow MapKit's own instruction asks for, in English or Indonesian, or `nil` when it names no direction.
    /// A roundabout or a U-turn wins; otherwise the first "left" or "right" counts, so a street name later in the
    /// sentence ("… onto Jalan Kiri") cannot change it.
    private static func Direction(saying instruction: String) -> TripMapGuidance.TurnDirection? {
        let text = instruction.lowercased()
        if text.contains("roundabout") || text.contains("bundaran") { return .roundabout }
        if text.contains("u-turn") || text.contains("putar balik") { return .uTurn }
        for word in text.split(whereSeparator: { $0.isLetter == false }) {
            if word == "left" || word == "kiri" { return .left }
            if word == "right" || word == "kanan" { return .right }
        }
        return nil
    }
}
