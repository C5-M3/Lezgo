#if DEBUG
import Foundation

/// Plays `SimulatedTripMapDrive`, sending one snapshot per second like live trip updates will (#83).
///
/// Debug builds only. Used by the trip map previews and by `DebugScreen` for simulator checks.
struct SimulatedTripMapService: TripMapService {
    /// Whose phone this is: `SimulatedTripMapDrive.agusID` for the leader, `budiID` for a member.
    var myParticipantID: UUID
    /// Seconds between updates; previews and the simulator use 1 second, as the real trip does.
    var interval: Duration = .seconds(1)
    /// How far into the drive to start, in seconds; a large value starts with the cars at the destination.
    var startSecond = 0

    func TripUpdates(tripID: UUID) -> AsyncStream<TripMapSnapshot> {
        AsyncStream { continuation in
            let task = Task {
                var elapsedSeconds = startSecond
                while Task.isCancelled == false {
                    continuation.yield(
                        SimulatedTripMapDrive.Snapshot(
                            elapsedSeconds: elapsedSeconds,
                            myParticipantID: myParticipantID,
                            now: .now
                        )
                    )
                    elapsedSeconds += 1
                    try? await Task.sleep(for: interval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
#endif
