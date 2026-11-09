//
//  MockDirectionsService.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
@testable import Lezgo

/// Returns the next result from a list for each call, and repeats the last one when the list runs out. Records the
/// points of every request. With `holdsRequests`, every request waits until `ReleaseRequests()`, like a slow network.
/// With `roads`, each path is worked out from the requested points instead, like a map of streets.
final class MockDirectionsService: DirectionsService {
    struct NoRoute: Error {}

    private var results: [Result<[Coordinate], NoRoute>]
    private(set) var requestedPoints: [[Coordinate]] = []
    var holdsRequests = false
    /// The road through the requested points, or `nil` for no road; replaces `results` when set.
    var roads: (([Coordinate]) -> [Coordinate]?)?
    private var heldRequests: [CheckedContinuation<Void, Never>] = []

    init(results: [Result<[Coordinate], NoRoute>]) {
        self.results = results
    }

    /// Lets the held requests, and every later one, return.
    func ReleaseRequests() {
        holdsRequests = false
        heldRequests.forEach { $0.resume() }
        heldRequests = []
    }

    func DrivingPath(through points: [Coordinate]) async throws -> [Coordinate] {
        requestedPoints.append(points)
        if holdsRequests {
            await withCheckedContinuation { heldRequests.append($0) }
        }
        if let roads {
            guard let path = roads(points) else { throw NoRoute() }
            return path
        }
        let result = results.count > 1 ? results.removeFirst() : results.first ?? .failure(NoRoute())
        return try result.get()
    }
}
