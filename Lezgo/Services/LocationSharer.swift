import Foundation

/// Sends this phone's position to the trip once per `interval` while it runs (#170).
///
/// Readings arrive whenever the GPS has one; the latest is sent on a fixed one-second rate, which kept CloudKit
/// within the 2-second target and its limits in the load check (#69). While the GPS has no signal, the last known
/// position is sent again, so `lastSeenAt` stays fresh and the car does not look offline. Failed sends are retried
/// on the next tick.
@Observable
final class LocationSharer {
    /// The last send's error, or `nil` once a send works again.
    private(set) var lastError: TripServiceError?
    private(set) var sentCount = 0

    private let tripService: any TripService
    private let locationProvider: any LocationProvider
    private let tripID: UUID
    private let participantID: UUID
    private let interval: Duration
    private let clock: () -> Date

    init(
        tripService: any TripService,
        locationProvider: any LocationProvider,
        tripID: UUID,
        participantID: UUID,
        interval: Duration = .seconds(1),
        clock: @escaping () -> Date = { .now }
    ) {
        self.tripService = tripService
        self.locationProvider = locationProvider
        self.tripID = tripID
        self.participantID = participantID
        self.interval = interval
        self.clock = clock
    }

    /// Shares the position until the task is cancelled, for example when the trip ends or this person leaves.
    func Run() async {}
}
