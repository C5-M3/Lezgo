//
//  MockLocationProvider.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation
@testable import Lezgo

/// GPS readings that a test sends by hand.
///
/// A listener that starts late still gets the readings sent before it, in order. On a busy test machine the sharer
/// can start listening after the test sent its first reading, and a lost reading made tests fail at random.
final class MockLocationProvider: LocationProvider {
    private var continuations: [AsyncStream<LocationReading>.Continuation] = []
    private var sent: [LocationReading] = []

    func Readings() -> AsyncStream<LocationReading> {
        let (stream, continuation) = AsyncStream.makeStream(of: LocationReading.self)
        sent.forEach { continuation.yield($0) }
        continuations.append(continuation)
        return stream
    }

    func Send(_ reading: LocationReading) {
        sent.append(reading)
        continuations.forEach { $0.yield(reading) }
    }
}
