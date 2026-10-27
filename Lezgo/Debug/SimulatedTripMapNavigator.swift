//
//  SimulatedTripMapNavigator.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

#if DEBUG
import Foundation

/// Rough turn-by-turn guidance along the simulated route, standing in for MapKit directions (#72).
///
/// It finds the route point nearest to the car, then takes the next bend of more than 20 degrees as the next turn,
/// and the rest of the route at 40 km/h as the time left. Debug builds only.
struct SimulatedTripMapNavigator: TripMapNavigator {
    private static let averageMetresPerSecond = 11.0
    private static let turnThresholdDegrees = 20.0

    func Guidance(from position: Coordinate, along state: TripState) async throws -> TripMapGuidance {
        let route = state.route?.polyline ?? state.waypoints.map(\.coordinate)
        guard route.count >= 2 else {
            return TripMapGuidance(
                direction: .straight,
                instruction: Instruction(for: .straight),
                distanceToTurn: Measurement(value: 0, unit: .meters),
                timeLeft: .zero
            )
        }

        let nearestIndex = route.indices.min {
            position.Distance(to: route[$0]) < position.Distance(to: route[$1])
        } ?? 0
        let nextIndex = min(nearestIndex + 1, route.count - 1)
        let remainingRoute = Array(route[nextIndex...])
        let remainingDistance = position.Distance(to: route[nextIndex])
            + zip(remainingRoute, remainingRoute.dropFirst()).reduce(0) { $0 + $1.0.Distance(to: $1.1) }

        let (turnIndex, direction) = NextTurn(in: route, after: nextIndex)
        let turnPath = [position] + Array(route[nextIndex...turnIndex])
        let distanceToTurn = zip(turnPath, turnPath.dropFirst()).reduce(0) { $0 + $1.0.Distance(to: $1.1) }

        return TripMapGuidance(
            direction: direction,
            instruction: Instruction(for: direction),
            distanceToTurn: Measurement(value: distanceToTurn, unit: .meters),
            timeLeft: .seconds(Int(remainingDistance / Self.averageMetresPerSecond))
        )
    }

    /// The first route point from `start` where the road bends by more than the threshold, or the destination.
    private func NextTurn(in route: [Coordinate], after start: Int) -> (Int, TripMapTurnDirection) {
        guard start >= 1 else { return (route.count - 1, .straight) }
        for index in start..<(route.count - 1) {
            let change = BearingChange(from: route[index - 1], through: route[index], to: route[index + 1])
            if change > Self.turnThresholdDegrees { return (index, .right) }
            if change < -Self.turnThresholdDegrees { return (index, .left) }
        }
        return (route.count - 1, .straight)
    }

    /// Change of heading at `middle`, in degrees: positive turns right, negative turns left.
    private func BearingChange(
        from start: Coordinate,
        through middle: Coordinate,
        to end: Coordinate
    ) -> Double {
        let change = Bearing(from: middle, to: end) - Bearing(from: start, to: middle)
        return (change + 540).truncatingRemainder(dividingBy: 360) - 180
    }

    private func Bearing(from start: Coordinate, to end: Coordinate) -> Double {
        let latitude1 = start.latitude * .pi / 180
        let latitude2 = end.latitude * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let y = sin(longitudeDelta) * cos(latitude2)
        let x = cos(latitude1) * sin(latitude2) - sin(latitude1) * cos(latitude2) * cos(longitudeDelta)
        return atan2(y, x) * 180 / .pi
    }

    /// Stand-in for `MKRoute.Step.instructions`, which MapKit localizes itself. Debug builds only.
    private func Instruction(for direction: TripMapTurnDirection) -> String {
        switch direction {
        case .left: "Turn left"
        case .right: "Turn right"
        case .straight: "Continue to the destination"
        }
    }
}
#endif
