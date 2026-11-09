//
//  TripMapWayBackPlanner.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import CoreLocation

/// Picks the road for a member's way back to the group's road, or for a shortcut past a loop the leader drove
/// (`specs/UserStories.md` → US-06, "Footprint").
///
/// The nearest point of the road is often a poor place to join it: it can be the start of a loop the leader drove,
/// or the junction behind the car. So it asks MapKit for a road to a few places on the group's road ahead and to the
/// leader, and keeps the one with the shortest road plus the group's road left from there to the leader.
struct TripMapWayBackPlanner {
    /// The points of the group's road asked for, the nearest to the car first; the leader is asked for too.
    static let maximumPlaces = 3
    /// Points asked for are at least this far apart along the road, so they are not three ways to one corner.
    static let placeSpacing: CLLocationDistance = 150
    /// How finely the road is searched for the points nearest the car.
    static let sampleSpacing: CLLocationDistance = 50
    /// Added to a road that starts by turning back: MapKit does not know which way the car faces, and a U-turn in
    /// traffic takes far longer than its few metres.
    static let uTurnPenalty: CLLocationDistance = 500
    /// A road that starts more than this many degrees off the car's heading turns back.
    static let uTurnAngle = 120.0

    let directionsService: any DirectionsService

    /// A way back and how long the drive to the leader is that way: the road, the group's road left from where it
    /// joins, and any U-turn penalty.
    struct Choice: Hashable {
        var path: [Coordinate]
        var length: CLLocationDistance
    }

    /// The best way back from `coordinate` to the group's road, joining it at least `earliest` metres along it.
    /// Without a leader ahead of that point, it is measured to the end of the road instead. `nil` when MapKit finds
    /// no road to any place.
    func Best(
        from coordinate: Coordinate,
        course: Double?,
        joiningAfter earliest: CLLocationDistance,
        in state: TripState
    ) async -> Choice? {
        let path = state.groupPath
        let lengths = PathTurns.LengthsAlong(path)
        guard let total = lengths.last else { return nil }
        let leader = LeaderPlace(in: state, on: path).flatMap { $0.along >= earliest ? $0 : nil }
        let end = leader?.along ?? total
        let places = Places(on: path, lengths: lengths, from: earliest, to: end, near: coordinate)
            + (leader.map { [$0] } ?? [])
        var best: Choice?
        for place in places {
            guard let road = try? await directionsService.DrivingPath(through: [coordinate, place.point]) else {
                continue
            }
            let penalty = TurnsBack(road, course: course) ? Self.uTurnPenalty : 0
            let length = (PathTurns.LengthsAlong(road).last ?? 0) + (end - place.along) + penalty
            if length < best?.length ?? .infinity {
                best = Choice(path: road, length: length)
            }
        }
        return best
    }

    /// A point of the group's road and how far along it the point is.
    private struct Place {
        var point: Coordinate
        var along: CLLocationDistance
    }

    /// The leader's car and how far along the group's road it is.
    private func LeaderPlace(in state: TripState, on path: [Coordinate]) -> Place? {
        guard let leaderCoordinate = state.leader?.coordinate,
              let position = RoutePosition.Locate(leaderCoordinate, on: path) else { return nil }
        return Place(point: leaderCoordinate, along: position.distanceAlongRoute)
    }

    /// Up to `maximumPlaces` points between `start` and `end` metres along `path`, the nearest to `coordinate` first,
    /// each at least `placeSpacing` along the road from the others.
    private func Places(
        on path: [Coordinate],
        lengths: [Double],
        from start: CLLocationDistance,
        to end: CLLocationDistance,
        near coordinate: Coordinate
    ) -> [Place] {
        guard start <= end else { return [] }
        let samples = stride(from: start, through: end, by: Self.sampleSpacing).compactMap { along in
            Point(at: along, on: path, lengths: lengths).map { Place(point: $0, along: along) }
        }
        var chosen: [Place] = []
        for sample in samples.sorted(by: { $0.point.Distance(to: coordinate) < $1.point.Distance(to: coordinate) }) {
            guard chosen.count < Self.maximumPlaces else { break }
            if chosen.allSatisfy({ abs($0.along - sample.along) >= Self.placeSpacing }) {
                chosen.append(sample)
            }
        }
        return chosen
    }

    /// The point `along` metres from the start of `path`, or `nil` past its end.
    private func Point(at along: CLLocationDistance, on path: [Coordinate], lengths: [Double]) -> Coordinate? {
        guard let leg = lengths.indices.dropLast().first(where: { lengths[$0 + 1] >= along }) else {
            return along == lengths.last ? path.last : nil
        }
        let legLength = lengths[leg + 1] - lengths[leg]
        let fraction = legLength > 0 ? (along - lengths[leg]) / legLength : 0
        let start = path[leg]
        let end = path[leg + 1]
        return Coordinate(
            latitude: start.latitude + (end.latitude - start.latitude) * fraction,
            longitude: start.longitude + (end.longitude - start.longitude) * fraction
        )
    }

    /// Whether `road` starts against the car's heading: its first 30 m point more than `uTurnAngle` away from it.
    private func TurnsBack(_ road: [Coordinate], course: Double?) -> Bool {
        guard let course, let start = road.first else { return false }
        let lengths = PathTurns.LengthsAlong(road)
        let ahead = road.indices.first { lengths[$0] >= PathTurns.headingDistance } ?? road.count - 1
        guard road[ahead] != start else { return false }
        let change = PathTurns.Bearing(from: start, to: road[ahead]) - course
        let normalized = (change + 540).truncatingRemainder(dividingBy: 360) - 180
        return abs(normalized) > Self.uTurnAngle
    }
}
