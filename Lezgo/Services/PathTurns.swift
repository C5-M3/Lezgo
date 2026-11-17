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
        guard let bend = Bend(in: path, lengths: lengths, at: index) else { return .straight }
        if abs(bend) > TripMapGuidance.TurnDirection.uTurnDegrees { return bend < 0 ? .uTurnLeft : .uTurnRight }
        if bend > threshold { return .right }
        if bend < -threshold { return .left }
        return .straight
    }

    /// How many degrees the road turns at `index`, comparing its heading over the 30 m before with the 30 m after:
    /// positive turns right, negative turns left. `nil` at either end of the path, where one side is missing.
    static func Bend(in path: [Coordinate], lengths: [Double], at index: Int) -> Double? {
        guard index > 0, index < path.count - 1 else { return nil }
        let before = path.indices[..<index].last { lengths[index] - lengths[$0] >= headingDistance } ?? 0
        guard path[before] != path[index], let headingOut = HeadingAfter(index, in: path, lengths: lengths) else {
            return nil
        }
        return Change(from: Bearing(from: path[before], to: path[index]), to: headingOut)
    }

    /// How many degrees the car turns through a roundabout that it enters on the line from `start` and leaves at
    /// `exit`, positive to the right (#331). MapKit's step runs from the last maneuver to the exit and includes the
    /// ring, so the heading in is the last straight stretch of at least 80 m before the exit: the ring and its entry
    /// curve are shorter than that. The heading out is the 30 m after the exit.
    static func ExitBend(in path: [Coordinate], lengths: [Double], from start: Int, exit: Int) -> Double? {
        guard start < exit, let headingOut = HeadingAfter(exit, in: path, lengths: lengths) else { return nil }
        return Change(from: HeadingIn(in: path, lengths: lengths, from: start, to: exit), to: headingOut)
    }

    /// The heading of the last stretch of at least 80 m, between `start` and `end`, that stays within 10 degrees;
    /// the heading of the line's first 30 m when there is none.
    private static func HeadingIn(in path: [Coordinate], lengths: [Double], from start: Int, to end: Int) -> Double {
        var index = end
        while index > start {
            let heading = Bearing(from: path[index - 1], to: path[index])
            var first = index - 1
            while first > start, abs(Change(from: heading, to: Bearing(from: path[first - 1], to: path[first]))) <= 10 {
                first -= 1
            }
            if lengths[index] - lengths[first] >= 80 { return heading }
            index = first
        }
        let ahead = path.indices[start...end].first { lengths[$0] - lengths[start] >= headingDistance } ?? end
        return Bearing(from: path[start], to: path[ahead])
    }

    /// The heading of the road over the 30 m after `index`, or `nil` when the path ends there.
    private static func HeadingAfter(_ index: Int, in path: [Coordinate], lengths: [Double]) -> Double? {
        guard index < path.count - 1 else { return nil }
        let after = path.indices[(index + 1)...].first { lengths[$0] - lengths[index] >= headingDistance }
            ?? path.count - 1
        guard path[index] != path[after] else { return nil }
        return Bearing(from: path[index], to: path[after])
    }

    /// The turn from one compass heading to another, in degrees from -180 to 180: positive is to the right.
    private static func Change(from headingIn: Double, to headingOut: Double) -> Double {
        (headingOut - headingIn + 540).truncatingRemainder(dividingBy: 360) - 180
    }

    /// The compass direction from `start` to `end`, in degrees clockwise from north (-180 to 180).
    static func Bearing(from start: Coordinate, to end: Coordinate) -> Double {
        let latitude1 = start.latitude * .pi / 180
        let latitude2 = end.latitude * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let y = sin(longitudeDelta) * cos(latitude2)
        let x = cos(latitude1) * sin(latitude2) - sin(latitude1) * cos(latitude2) * cos(longitudeDelta)
        return atan2(y, x) * 180 / .pi
    }
}
