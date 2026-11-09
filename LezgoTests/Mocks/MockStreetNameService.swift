//
//  MockStreetNameService.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
@testable import Lezgo

/// Returns the next result from a list for each call, and repeats the last one when the list runs out.
final class MockStreetNameService: StreetNameService {
    struct LookupFailed: Error {}

    private var results: [Result<String?, LookupFailed>]
    private(set) var requestedCoordinates: [Coordinate] = []

    init(results: [Result<String?, LookupFailed>] = [.success("Ahmad Yani Street")]) {
        self.results = results
    }

    func StreetName(at coordinate: Coordinate) async throws -> String? {
        requestedCoordinates.append(coordinate)
        let result = results.count > 1 ? results.removeFirst() : results.first ?? .failure(LookupFailed())
        return try result.get()
    }
}
