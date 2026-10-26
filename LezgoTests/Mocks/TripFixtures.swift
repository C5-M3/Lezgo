import Foundation
@testable import Lezgo

/// The trip from `specs/UserStories.md` → US-06: leader Agus, members Budi and Citra, from Tunjungan Plaza through
/// checkpoint Ciputra World to Pakuwon mall.
enum TripFixtures {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let tripID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let agusID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1") ?? UUID()
    static let budiID = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1") ?? UUID()

    static let tunjunganPlaza = Coordinate(latitude: -7.2622, longitude: 112.7387)
    static let ciputraWorld = Coordinate(latitude: -7.2923, longitude: 112.7190)
    static let pakuwonMall = Coordinate(latitude: -7.2893, longitude: 112.6766)

    static func Trip(currentWaypointIndex: Int = 1) -> Lezgo.Trip {
        Lezgo.Trip(
            id: tripID,
            roomCode: "897654",
            status: .inTrip,
            leaderParticipantID: agusID,
            currentWaypointIndex: currentWaypointIndex,
            routeVersion: 1,
            createdAt: now,
            startedAt: now,
            endedAt: nil
        )
    }

    static func Waypoint(orderIndex: Int, kind: WaypointKind = .checkpoint) -> Lezgo.Waypoint {
        Lezgo.Waypoint(
            id: UUID(),
            tripID: tripID,
            orderIndex: orderIndex,
            kind: kind,
            name: "Ciputra World",
            coordinate: ciputraWorld
        )
    }

    static func Participant(id: UUID = budiID, lastSeenSecondsAgo: TimeInterval = 1) -> Lezgo.Participant {
        Lezgo.Participant(
            id: id,
            tripID: tripID,
            userRecordID: "_user-\(id.uuidString)",
            displayName: "Budi",
            carDescription: "White Brio",
            coordinate: tunjunganPlaza,
            speedKmh: 40,
            motionState: .driving,
            alert: .none,
            lastSeenAt: now.addingTimeInterval(-lastSeenSecondsAgo)
        )
    }
}
