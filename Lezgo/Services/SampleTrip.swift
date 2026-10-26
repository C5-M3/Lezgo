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
    static let tripID = UUID(uuidString: "5A3B1E00-0000-0000-0000-000000000001") ?? UUID()
    static let agusID = UUID(uuidString: "5A3B1E00-0000-0000-0000-0000000000A1") ?? UUID()
    static let budiID = UUID(uuidString: "5A3B1E00-0000-0000-0000-0000000000B1") ?? UUID()
    static let citraID = UUID(uuidString: "5A3B1E00-0000-0000-0000-0000000000C1") ?? UUID()
    static let roomCode = "897654"

    private static let tunjunganPlaza = Coordinate(latitude: -7.2622, longitude: 112.7387)
    private static let ciputraWorld = Coordinate(latitude: -7.2923, longitude: 112.7190)
    private static let pakuwonMall = Coordinate(latitude: -7.2893, longitude: 112.6766)
    private static let polyline = [
        tunjunganPlaza,
        Coordinate(latitude: -7.2702, longitude: 112.7358),
        Coordinate(latitude: -7.2795, longitude: 112.7300),
        Coordinate(latitude: -7.2893, longitude: 112.7218),
        ciputraWorld,
        Coordinate(latitude: -7.2905, longitude: 112.7030),
        Coordinate(latitude: -7.2890, longitude: 112.6850),
        pakuwonMall
    ]

    /// An in-memory service whose store holds the sample trip, used from the phone of `me`.
    static func Service(status: TripStatus = .lobby, me participantID: UUID = agusID) -> InMemoryTripService {
        InMemoryTripService(
            store: InMemoryTripStore(trips: [State(status: status)]),
            userRecordID: UserRecordID(of: participantID)
        )
    }

    /// The sample trip in the given status, as the store keeps it.
    static func State(status: TripStatus = .lobby, now: Date = .now) -> TripState {
        let isOnTheRoad = status == .inTrip
        return TripState(
            trip: Trip(
                id: tripID,
                roomCode: roomCode,
                status: status,
                leaderParticipantID: agusID,
                currentWaypointIndex: isOnTheRoad ? 1 : 0,
                routeVersion: 1,
                createdAt: now.addingTimeInterval(-900),
                startedAt: isOnTheRoad ? now.addingTimeInterval(-600) : nil,
                endedAt: nil
            ),
            waypoints: [
                Stop(0, .start, "Tunjungan Plaza", at: tunjunganPlaza),
                Stop(1, .checkpoint, "Ciputra World", at: ciputraWorld),
                Stop(2, .destination, "Pakuwon mall", at: pakuwonMall)
            ],
            participants: [
                Member(agusID, "Agus", car: "Black Avanza", at: isOnTheRoad ? polyline[3] : tunjunganPlaza, now: now),
                Member(budiID, "Budi", car: "White Brio", at: isOnTheRoad ? polyline[2] : tunjunganPlaza, now: now),
                Member(citraID, "Citra", car: "Red Jazz", at: tunjunganPlaza, now: now.addingTimeInterval(-180))
            ],
            route: Route(id: UUID(), tripID: tripID, version: 1, polyline: polyline)
        )
    }

    private static func Stop(
        _ index: Int,
        _ kind: WaypointKind,
        _ name: String,
        at coordinate: Coordinate
    ) -> Waypoint {
        Waypoint(id: UUID(), tripID: tripID, orderIndex: index, kind: kind, name: name, coordinate: coordinate)
    }

    private static func Member(
        _ id: UUID,
        _ name: String,
        car: String,
        at coordinate: Coordinate,
        now: Date
    ) -> Participant {
        Participant(
            id: id,
            tripID: tripID,
            userRecordID: UserRecordID(of: id),
            displayName: name,
            carDescription: car,
            coordinate: coordinate,
            speedKmh: 0,
            motionState: .stopped,
            alert: .none,
            lastSeenAt: now
        )
    }

    private static func UserRecordID(of participantID: UUID) -> String {
        "_sample-\(participantID.uuidString)"
    }
}
#endif
