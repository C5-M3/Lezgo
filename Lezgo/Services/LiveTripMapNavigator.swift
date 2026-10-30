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
    /// A bend sharper than this, in degrees, shows a left or right arrow.
    private static let turnThresholdDegrees = 20.0
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
            timeLeft: .seconds(Int(timeLeft.rounded()))
        )
    }
}

// MARK: - Kept directions

extension LiveTripMapNavigator {
    /// One answer from MapKit as one road, with every turn's place along it.
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
            let lengths = Self.LengthsAlong(path)

            routeVersion = state.trip.routeVersion
            currentWaypointIndex = state.trip.currentWaypointIndex
            self.fetchedAt = fetchedAt
            expectedTravelTime = directions.expectedTravelTime
            self.path = path
            length = lengths.last ?? 0
            turns = zip(directions.steps, stepStarts).dropFirst().map { step, start in
                Turn(
                    instruction: step.instruction,
                    direction: Self.Direction(in: path, at: start),
                    distanceAlongRoute: lengths[start]
                )
            }
        }

        func IsFor(_ state: TripState) -> Bool {
            routeVersion == state.trip.routeVersion && currentWaypointIndex == state.trip.currentWaypointIndex
        }

        /// Metres from the start of `path` to each of its points.
        private static func LengthsAlong(_ path: [Coordinate]) -> [Double] {
            zip(path, path.dropFirst()).reduce(into: [0]) { lengths, segment in
                let segmentLength = RoutePosition.Locate(segment.1, on: [segment.0, segment.1])?.distanceAlongRoute ?? 0
                lengths.append((lengths.last ?? 0) + segmentLength)
            }
        }

        /// Which way the road bends at `index`: compares the heading into it with the heading out of it.
        private static func Direction(in path: [Coordinate], at index: Int) -> TripMapGuidance.TurnDirection {
            guard index > 0, index < path.count - 1 else { return .straight }
            let headingIn = Bearing(from: path[index - 1], to: path[index])
            let change = Bearing(from: path[index], to: path[index + 1]) - headingIn
            let normalized = (change + 540).truncatingRemainder(dividingBy: 360) - 180
            if normalized > LiveTripMapNavigator.turnThresholdDegrees { return .right }
            if normalized < -LiveTripMapNavigator.turnThresholdDegrees { return .left }
            return .straight
        }

        private static func Bearing(from start: Coordinate, to end: Coordinate) -> Double {
            let latitude1 = start.latitude * .pi / 180
            let latitude2 = end.latitude * .pi / 180
            let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
            let y = sin(longitudeDelta) * cos(latitude2)
            let x = cos(latitude1) * sin(latitude2) - sin(latitude1) * cos(latitude2) * cos(longitudeDelta)
            return atan2(y, x) * 180 / .pi
        }
    }
}
