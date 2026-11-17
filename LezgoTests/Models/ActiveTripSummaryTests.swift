//
//  ActiveTripSummaryTests.swift
//  LezgoTests
//

import Foundation
import Testing
@testable import Lezgo

@Suite("ActiveTripSummary Tests")
struct ActiveTripSummaryTests {

    @Test("A summary made from a session keeps every participant's avatar, in the Trip Room order")
    func summaryKeepsTheRealAvatars() {
        let session = TripSession(myParticipantID: SampleTrip.budiID, state: SampleTrip.State())

        let summary = ActiveTripSummary.From(session: session)

        #expect(summary.memberAvatars == [.yellow, .purple, .pink, .blue, .green])
    }

    @Test("A summary saved before avatars were kept still loads, with no avatars")
    func summaryWithoutAvatarsStillLoads() throws {
        let saved = """
        {"tripID":"5A3B1E00-0000-0000-0000-000000000001","myParticipantID":"5A3B1E00-0000-0000-0000-0000000000B1",\
        "roomCode":"897654","startName":"Start","destinationName":"End","memberNames":["Agus","Budi"]}
        """

        let summary = try JSONDecoder().decode(ActiveTripSummary.self, from: Data(saved.utf8))

        #expect(summary.memberNames == ["Agus", "Budi"])
        #expect(summary.memberAvatars.isEmpty)
    }

    @Test("Avatars survive being saved and loaded")
    func avatarsSurviveSaveAndLoad() throws {
        let summary = ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            roomCode: SampleTrip.roomCode,
            startName: "Start",
            destinationName: "End",
            memberNames: ["Agus", "Budi"],
            memberAvatars: [.yellow, .blue]
        )

        let loaded = try JSONDecoder().decode(ActiveTripSummary.self, from: JSONEncoder().encode(summary))

        #expect(loaded.memberAvatars == [.yellow, .blue])
    }
}
