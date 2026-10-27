import Foundation
@testable import Lezgo

/// Sends a fixed list of snapshots, then finishes the stream.
final class MockTripMapService: TripMapService {
    private let snapshots: [TripMapSnapshot]
    private(set) var requestedTripIDs: [UUID] = []
    private(set) var exitedParticipantIDs: [UUID] = []
    private(set) var endedByLeaderIDs: [UUID] = []
    /// When set, `ExitTrip` and `EndTrip` throw it.
    var failure: TripServiceError?

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

    func ExitTrip(tripID: UUID, participantID: UUID) async throws {
        if let failure { throw failure }
        exitedParticipantIDs.append(participantID)
    }

    func EndTrip(tripID: UUID, by leaderID: UUID) async throws {
        if let failure { throw failure }
        endedByLeaderIDs.append(leaderID)
    }
}
