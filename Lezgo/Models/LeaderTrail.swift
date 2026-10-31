//
//  LeaderTrail.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import CoreLocation

/// The road the leader has driven, their footprint (`specs/UserStories.md` → US-06, "Footprint"). Members behind the
/// leader follow it, so the group stays on one road even after the leader leaves the planned route.
struct LeaderTrail: Hashable {
    /// A new point only once the leader is this far from the last one, so GPS noise while standing still does not
    /// fill the trail with points in one place.
    static let spacing: CLLocationDistance = 20
    /// At 20 m apart, about 30 km of road: far more than any member falls behind. Older points are dropped.
    static let maximumPointCount = 1_500

    private(set) var points: [Coordinate]

    init(points: [Coordinate] = []) {
        self.points = Array(points.suffix(Self.maximumPointCount))
    }

    /// Adds the leader's position when it is far enough from the last point. Returns whether it was added.
    @discardableResult
    mutating func Append(_ coordinate: Coordinate) -> Bool {
        if let last = points.last, last.Distance(to: coordinate) < Self.spacing { return false }
        points.append(coordinate)
        if points.count > Self.maximumPointCount {
            points.removeFirst(points.count - Self.maximumPointCount)
        }
        return true
    }
}
