import Foundation
@testable import Lezgo

/// Returns the next result from a list for each call, and repeats the last one when the list runs out.
final class MockTripMapNavigator: TripMapNavigator {
    struct NavigationUnavailable: Error {}

    private var results: [Result<TripMapGuidance, NavigationUnavailable>]
    private(set) var requestedPositions: [Coordinate] = []

    init(results: [Result<TripMapGuidance, NavigationUnavailable>]) {
        self.results = results
    }

    func Guidance(from position: Coordinate, along state: TripState) async throws -> TripMapGuidance {
        requestedPositions.append(position)
        let result = results.count > 1 ? results.removeFirst() : results.first ?? .failure(NavigationUnavailable())
        return try result.get()
    }
}
