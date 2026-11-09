//
//  TripPhones.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Three phones (Agus, Budi and Citra) in one trip, using either `TripService` implementation.
///
/// The `TripService*Tests` suites run every test once per `Kind`, so `InMemoryTripService` and `LiveTripService`
/// follow exactly the same rules (ADR 0017).
struct TripPhones {
    enum Kind: CaseIterable, CustomTestStringConvertible {
        case inMemory
        case live

        var testDescription: String {
            switch self {
            case .inMemory: "InMemoryTripService"
            case .live: "LiveTripService"
            }
        }
    }

    let agus: any TripService
    let budi: any TripService
    let citra: any TripService

    init(_ kind: Kind) {
        let userRecordNames = ["_agus0001", "_budi7F3A", "_citra42C"]
        let phones: [any TripService]
        switch kind {
        case .inMemory:
            let store = InMemoryTripStore()
            phones = userRecordNames.map { name in
                InMemoryTripService(store: store, userRecordID: name, clock: { TripFixtures.now })
            }
        case .live:
            let server = FakeCloudServer()
            phones = userRecordNames.map { name in
                LiveTripService(
                    database: FakeCloudDatabase(server: server, userRecordName: name),
                    clock: { TripFixtures.now },
                    pollInterval: .milliseconds(5)
                )
            }
        }
        agus = phones[0]
        budi = phones[1]
        citra = phones[2]
    }

    /// Agus creates the Tunjungan Plaza → Pakuwon mall trip; Budi and Citra join it.
    func MakeGroup() async throws -> TripGroup {
        let created = try await agus.CreateTrip(
            plan: TripPlanFixtures.tunjunganToPakuwon,
            profile: TripPlanFixtures.agusProfile
        )
        let roomCode = created.state.trip.roomCode
        let budiSession = try await budi.JoinTrip(roomCode: roomCode, profile: TripPlanFixtures.budiProfile)
        let citraSession = try await citra.JoinTrip(roomCode: roomCode, profile: TripPlanFixtures.citraProfile)
        return TripGroup(
            tripID: created.state.trip.id,
            roomCode: roomCode,
            agusID: created.myParticipantID,
            budiID: budiSession.myParticipantID,
            citraID: citraSession.myParticipantID
        )
    }

    /// Makes the group and starts the trip.
    func MakeGroupOnTheRoad() async throws -> TripGroup {
        let group = try await MakeGroup()
        try await agus.StartTrip(tripID: group.tripID, by: group.agusID)
        return group
    }

    /// Budi's participant as Agus's phone sees it.
    func Budi(in group: TripGroup) async throws -> Participant? {
        try await agus.FetchTrip(tripID: group.tripID).participants.first { $0.id == group.budiID }
    }
}
