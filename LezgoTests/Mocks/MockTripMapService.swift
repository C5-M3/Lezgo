import Foundation
@testable import Lezgo

/// Sends a fixed list of snapshots, then finishes the stream.
final class MockTripMapService: TripMapService {
    private let snapshots: [TripMapSnapshot]
    private(set) var requestedTripIDs: [UUID] = []

    init(snapshots: [TripMapSnapshot]) {
        self.snapshots = snapshots
    }

    func TripUpdates(tripID: UUID) -> AsyncStream<TripMapSnapshot> {
        requestedTripIDs.append(tripID)
        return AsyncStream { continuation in
            for snapshot in snapshots {
                continuation.yield(snapshot)
            }
            continuation.finish()
        }
    }
}
