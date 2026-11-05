//
//  PathTurns.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation

/// Turns read from the shape of a road line alone, for lines without MapKit's instructions: the gaps in MapKit's own
/// steps, and the leader's footprint, which only records where the leader drove (`LeaderTrail`).
enum PathTurns {
    /// How far before and after a point the road's heading is measured, in metres, so a small kink right at the
    /// corner does not hide the turn.
    static let headingDistance = 30.0

    /// Metres from the start of `path` to each of its points.
    static func LengthsAlong(_ path: [Coordinate]) -> [Double] {
        zip(path, path.dropFirst()).reduce(into: [0]) { lengths, segment in
            let segmentLength = RoutePosition.Locate(segment.1, on: [segment.0, segment.1])?.distanceAlongRoute ?? 0
            lengths.append((lengths.last ?? 0) + segmentLength)
        }
    }

    /// Which way the road bends at `index`: compares its heading over the 30 m before with the 30 m after. A bend of
    /// more than `threshold` degrees is a turn, and one of more than 150 degrees turns back.
    static func Direction(
        in path: [Coordinate],
        lengths: [Double],
        at index: Int,
        threshold: Double
    ) -> TripMapGuidance.TurnDirection {
        guard index > 0, index < path.count - 1 else { return .straight }
        let before = path.indices[..<index].last { lengths[index] - lengths[$0] >= headingDistance } ?? 0
        let after = path.indices[(index + 1)...].first { lengths[$0] - lengths[index] >= headingDistance }
            ?? path.count - 1
        guard path[before] != path[index], path[index] != path[after] else { return .straight }
        let headingIn = Bearing(from: path[before], to: path[index])
        let change = Bearing(from: path[index], to: path[after]) - headingIn
        let normalized = (change + 540).truncatingRemainder(dividingBy: 360) - 180
        if abs(normalized) > 150 { return .uTurn }
        if normalized > threshold { return .right }
        if normalized < -threshold { return .left }
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
