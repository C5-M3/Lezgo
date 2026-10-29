//
//  DirectionsService.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation

/// Finds the road path through a list of points, for the automatic reroute when the leader leaves the route.
///
/// `LiveDirectionsService` asks MapKit; tests use `MockDirectionsService`.
protocol DirectionsService {
    /// The driving path from the first point through every other point in order, as one line.
    /// - Throws: when there is no network or no drivable road between two points.
    func DrivingPath(through points: [Coordinate]) async throws -> [Coordinate]
}
