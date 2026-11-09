//
//  MockDrivingDirectionsService.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 30/10/26.
//

import Foundation
@testable import Lezgo

/// Returns the next result from a list for each call, and repeats the last one when the list runs out. Records the
/// points of every request.
final class MockDrivingDirectionsService: DrivingDirectionsService {
    struct NoRoute: Error {}

    private var results: [Result<DrivingDirections, NoRoute>]
    private(set) var requestedPoints: [[Coordinate]] = []

    init(results: [Result<DrivingDirections, NoRoute>]) {
        self.results = results
    }

    func Directions(through points: [Coordinate]) async throws -> DrivingDirections {
        requestedPoints.append(points)
        let result = results.count > 1 ? results.removeFirst() : results.first ?? .failure(NoRoute())
        return try result.get()
    }
}
