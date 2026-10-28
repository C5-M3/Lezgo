//
//  TripRoomViewModelRemoveTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Removing participants from the Trip Room (US-05, "Remove members").
@MainActor
struct TripRoomViewModelRemoveTests {
    /// Only the leader may remove someone. A member's phone must not even ask the service, which would refuse with
    /// `.notAllowed` and show an error.
    @Test func MemberCannotRemoveParticipant() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: state
        )
        let citra = try #require(state.participants.first(where: { $0.id == SampleTrip.citraID }))

        #expect(viewModel.CanKick(participant: citra) == false)

        try await viewModel.RemoveParticipant(id: SampleTrip.citraID)

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.participants.contains(where: { $0.id == SampleTrip.citraID }))
    }
}
