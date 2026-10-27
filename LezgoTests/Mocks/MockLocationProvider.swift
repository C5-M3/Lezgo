//
//  MockLocationProvider.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation
@testable import Lezgo

/// GPS readings that a test sends by hand.
final class MockLocationProvider: LocationProvider {
    private var continuations: [AsyncStream<LocationReading>.Continuation] = []

    func Readings() -> AsyncStream<LocationReading> {
        let (stream, continuation) = AsyncStream.makeStream(of: LocationReading.self)
        continuations.append(continuation)
        return stream
    }

    func Send(_ reading: LocationReading) {
        continuations.forEach { $0.yield(reading) }
    }
}
