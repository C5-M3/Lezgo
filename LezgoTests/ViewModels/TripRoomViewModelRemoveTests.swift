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

    /// The leader can swipe every row, their own too: there "Kick" shows but is disabled (lo-fi
    /// "SLIDE DELETE IF LEADER"), so the leader sees why they cannot remove themselves.
    @Test func LeaderSwipesEveryRowButCannotKickThemselves() throws {
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.agusID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )
        let agus = try #require(state.participants.first(where: { $0.id == SampleTrip.agusID }))

        #expect(viewModel.showsKickSwipe == true)
        #expect(viewModel.CanKick(participant: agus) == false)
    }

    @Test func MemberHasNoKickSwipe() {
        let viewModel = TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.budiID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby)
        )

        #expect(viewModel.showsKickSwipe == false)
    }

    /// In Select mode the rows are ticked, not swiped.
    @Test func SelectModeHidesTheKickSwipe() {
        let viewModel = TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.agusID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: SampleTrip.State(status: .lobby)
        )

        viewModel.ToggleSelectionMode()

        #expect(viewModel.showsKickSwipe == false)
    }
}
