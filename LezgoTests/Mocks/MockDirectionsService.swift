//
//  MockDirectionsService.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
@testable import Lezgo

/// Returns the next result from a list for each call, and repeats the last one when the list runs out. Records the
/// points of every request.
final class MockDirectionsService: DirectionsService {
    struct NoRoute: Error {}

    private var results: [Result<[Coordinate], NoRoute>]
    private(set) var requestedPoints: [[Coordinate]] = []

    init(results: [Result<[Coordinate], NoRoute>]) {
        self.results = results
    }

    func DrivingPath(through points: [Coordinate]) async throws -> [Coordinate] {
        requestedPoints.append(points)
        let result = results.count > 1 ? results.removeFirst() : results.first ?? .failure(NoRoute())
        return try result.get()
    }
}
