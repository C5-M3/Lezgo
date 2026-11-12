//
//  MockPlaceLookupService.swift
//  LezgoTests
//

import Foundation
@testable import Lezgo

/// Answers address and nearby lookups from lists the test sets, and records what was asked.
final class MockPlaceLookupService: PlaceLookupService {
    struct LookupFailed: Error {}

    var addressResults: [Result<PlaceAddress?, LookupFailed>]
    var nearbyResult: Result<[NearbyPlace], LookupFailed>
    private(set) var requestedAddresses: [Coordinate] = []
    private(set) var requestedNearby: [Coordinate] = []

    /// Each address call returns the next result; the last one repeats when the list runs out.
    init(
        addressResults: [Result<PlaceAddress?, LookupFailed>] = [.success(PlaceAddress(street: "Jl. Raya Darmo", area: "Surabaya"))],
        nearbyResult: Result<[NearbyPlace], LookupFailed> = .success([])
    ) {
        self.addressResults = addressResults
        self.nearbyResult = nearbyResult
    }

    func Address(at coordinate: Coordinate) async throws -> PlaceAddress? {
        requestedAddresses.append(coordinate)
        let result = addressResults.count > 1 ? addressResults.removeFirst() : addressResults.first ?? .failure(LookupFailed())
        return try result.get()
    }

    func NearbyPlaces(around coordinate: Coordinate) async throws -> [NearbyPlace] {
        requestedNearby.append(coordinate)
        return try nearbyResult.get()
    }
}
