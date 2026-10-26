import Foundation
@testable import Lezgo

/// Three phones (Agus, Budi and Citra) that share one in-memory store, like three cars on one server.
struct InMemoryPhones {
    let store = InMemoryTripStore()
    let agus: InMemoryTripService
    let budi: InMemoryTripService
    let citra: InMemoryTripService

    init() {
        agus = InMemoryTripService(store: store, userRecordID: "_agus0001", clock: { TripFixtures.now })
        budi = InMemoryTripService(store: store, userRecordID: "_budi7F3A", clock: { TripFixtures.now })
        citra = InMemoryTripService(store: store, userRecordID: "_citra42C", clock: { TripFixtures.now })
    }

    /// Agus creates the Tunjungan Plaza → Pakuwon mall trip; Budi and Citra join it.
    func MakeGroup() async throws -> InMemoryGroup {
        let created = try await agus.CreateTrip(
            plan: TripPlanFixtures.tunjunganToPakuwon,
            profile: TripPlanFixtures.agusProfile
        )
        let roomCode = created.state.trip.roomCode
        let budiSession = try await budi.JoinTrip(roomCode: roomCode, profile: TripPlanFixtures.budiProfile)
        let citraSession = try await citra.JoinTrip(roomCode: roomCode, profile: TripPlanFixtures.citraProfile)
        return InMemoryGroup(
            tripID: created.state.trip.id,
            roomCode: roomCode,
            agusID: created.myParticipantID,
            budiID: budiSession.myParticipantID,
            citraID: citraSession.myParticipantID
        )
    }

    /// Makes the group and starts the trip.
    func MakeGroupOnTheRoad() async throws -> InMemoryGroup {
        let group = try await MakeGroup()
        try await agus.StartTrip(tripID: group.tripID, by: group.agusID)
        return group
    }

    /// Budi's participant as Agus's phone sees it.
    func Budi(in group: InMemoryGroup) async throws -> Participant? {
        try await agus.FetchTrip(tripID: group.tripID).participants.first { $0.id == group.budiID }
    }
}
