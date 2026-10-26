#if DEBUG
import Foundation

/// A ready-made trip for previews and `DebugScreen`, built without waiting on any async call.
///
/// It is the US-06 trip from `specs/UserStories.md`: leader Agus, members Budi and Citra, from Tunjungan Plaza
/// through checkpoint Ciputra World to Pakuwon mall. Citra is offline. Debug builds only.
///
/// ```swift
/// #Preview("Member") {
///     let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
///     let viewModel = TripRoomViewModel(
///         tripService: service,
///         tripID: SampleTrip.tripID,
///         myParticipantID: SampleTrip.budiID
///     )
///     TripRoomView(viewModel: viewModel)
/// }
/// ```
enum SampleTrip {
    static let tripID = UUID()
    static let agusID = UUID()
    static let budiID = UUID()
    static let citraID = UUID()
    static let roomCode = "897654"

    /// An in-memory service whose store holds the sample trip, used from the phone of `me`.
    static func Service(status: TripStatus = .lobby, me participantID: UUID = agusID) -> InMemoryTripService {
        InMemoryTripService(store: InMemoryTripStore(trips: []), userRecordID: "")
    }

    /// The sample trip in the given status, as the store keeps it.
    static func State(status: TripStatus = .lobby, now: Date = .now) -> TripState {
        TripState(
            trip: Trip(
                id: tripID,
                roomCode: roomCode,
                status: status,
                leaderParticipantID: agusID,
                currentWaypointIndex: 0,
                routeVersion: 1,
                createdAt: now,
                startedAt: nil,
                endedAt: nil
            ),
            waypoints: [],
            participants: [],
            route: nil
        )
    }
}
#endif
