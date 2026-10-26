#if DEBUG
import Foundation
import Observation

/// A developer tool that drives the real `TripService` on a phone, to check iCloud sync between phones (#111).
///
/// Open it with `-DebugScreen syncCheck`. Debug builds only; its text is for developers and is not localized.
@Observable
final class SyncCheckViewModel {
    private(set) var session: TripSession?
    private(set) var state: TripState?
    private(set) var log: [SyncCheckLogEntry] = []
    private(set) var errorMessage: String?
    private(set) var isBusy = false
    var roomCodeInput = ""

    private let tripService: any TripService
    private let clock: () -> Date

    init(tripService: any TripService, clock: @escaping () -> Date = { .now }) {
        self.tripService = tripService
        self.clock = clock
    }

    var myParticipantID: UUID? { nil }
    var isLeader: Bool { false }
    var canJoin: Bool { false }

    func CreateTrip() async {}
    func JoinTrip() async {}
    func StartTrip() async {}
    func HandOverLead(to participantID: UUID) async {}
    func EndTrip() async {}

    /// Follows the trip until the task is cancelled.
    func Listen() async {}

    /// Shows a new state and logs what changed since the last one.
    func Apply(_ newState: TripState) {}
}
#endif
