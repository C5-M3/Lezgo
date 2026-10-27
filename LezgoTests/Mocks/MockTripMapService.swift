import Foundation
@testable import Lezgo

/// Sends a fixed list of snapshots, then finishes the stream.
final class MockTripMapService: TripMapService {
    private let snapshots: [TripMapSnapshot]
    private var continuation: AsyncStream<TripMapSnapshot>.Continuation?
    private(set) var requestedTripIDs: [UUID] = []
    private(set) var exitedParticipantIDs: [UUID] = []
    private(set) var endedByLeaderIDs: [UUID] = []
    /// When set, `ExitTrip` and `EndTrip` throw it.
    var failure: TripServiceError?
    /// Sent while `ExitTrip` or `EndTrip` is on its way, like an update from the cloud arriving before the request
    /// returns. When set, the stream stays open after `snapshots`.
    var snapshotWhileLeaving: TripMapSnapshot?
    /// Runs after `snapshotWhileLeaving` was sent, before `ExitTrip` or `EndTrip` returns.
    var whileLeaving: (() async -> Void)?

    init(snapshots: [TripMapSnapshot]) {
        self.snapshots = snapshots
    }

    func TripUpdates(tripID: UUID) -> AsyncStream<TripMapSnapshot> {
        requestedTripIDs.append(tripID)
        return AsyncStream { continuation in
            for snapshot in snapshots {
                continuation.yield(snapshot)
            }
            if snapshotWhileLeaving == nil {
                continuation.finish()
            } else {
                self.continuation = continuation
            }
        }
    }

    func ExitTrip(tripID: UUID, participantID: UUID) async throws {
        if let failure { throw failure }
        await SendWhileLeaving()
        exitedParticipantIDs.append(participantID)
    }

    func EndTrip(tripID: UUID, by leaderID: UUID) async throws {
        if let failure { throw failure }
        await SendWhileLeaving()
        endedByLeaderIDs.append(leaderID)
    }

    private func SendWhileLeaving() async {
        guard let snapshotWhileLeaving else { return }
        continuation?.yield(snapshotWhileLeaving)
        await whileLeaving?()
    }
}
