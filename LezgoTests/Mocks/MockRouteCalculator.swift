//
//  MockRouteCalculator.swift
//  LezgoTests
//

import Foundation
@testable import Lezgo

/// Holds every route calculation until the test finishes it, so a test chooses the order the answers come back in.
final class MockRouteCalculator: RouteCalculating {
    private var pending: [CheckedContinuation<[RouteLeg], any Error>] = []

    var pendingCount: Int { pending.count }

    func calculateMultiStopLegs(points: [RoutePoint]) async throws -> [RouteLeg] {
        try await withCheckedThrowingContinuation { pending.append($0) }
    }

    func Finish(call index: Int, with result: Result<[RouteLeg], any Error>) {
        pending[index].resume(with: result)
    }
}
