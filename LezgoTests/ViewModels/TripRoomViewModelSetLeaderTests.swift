//
//  TripRoomViewModelSetLeaderTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 29/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Handing over the lead in the Trip Room (US-05, "Hand over the lead").
@MainActor
struct TripRoomViewModelSetLeaderTests {
    /// The leader can swipe every row, their own too: there "Set Lead" shows but is disabled (lo-fi
    /// "SET LEAD IF LEADERS IS SELECTED VIA SLIDER"), so the leader sees why they cannot pick themselves.
    @Test func LeaderSwipesEveryRowButCannotSetLeadOnThemselves() throws {
        let state = SampleTrip.State(status: .lobby)
        let viewModel = MakeViewModel(me: SampleTrip.agusID, state: state)
        let agus = try #require(state.participants.first(where: { $0.id == SampleTrip.agusID }))
        let budi = try #require(state.participants.first(where: { $0.id == SampleTrip.budiID }))

        #expect(viewModel.showsSetLeaderSwipe == true)
        #expect(viewModel.CanSetLeader(participant: agus) == false)
        #expect(viewModel.CanSetLeader(participant: budi) == true)
    }

    @Test func MemberHasNoSetLeadSwipe() {
        let viewModel = MakeViewModel(me: SampleTrip.budiID, state: SampleTrip.State(status: .lobby))

        #expect(viewModel.showsSetLeaderSwipe == false)
    }

    /// In Select mode the rows are ticked, not swiped.
    @Test func SelectModeHidesTheSetLeadSwipe() {
        let viewModel = MakeViewModel(me: SampleTrip.agusID, state: SampleTrip.State(status: .lobby))

        viewModel.ToggleSelectionMode()

        #expect(viewModel.showsSetLeaderSwipe == false)
    }

    /// Only the leader may hand over the lead. A member's phone must not even ask the service.
    @Test func MemberCannotHandOverTheLead() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = MakeViewModel(me: SampleTrip.budiID, state: state, service: service)
        let citra = try #require(state.participants.first(where: { $0.id == SampleTrip.citraID }))

        await viewModel.HandOverLead(to: citra)

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.trip.leaderParticipantID == SampleTrip.agusID)
        #expect(viewModel.errorMessage == nil)
    }

    /// "Budi has the crown and sees Start Trip, and Agus sees Waiting for others ...": both phones swap their
    /// leader controls once the new leader arrives in the trip updates.
    @Test func HandOverSwapsTheLeaderControlsOnBothPhones() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let agusPhone = MakeViewModel(me: SampleTrip.agusID, service: service)
        let budiPhone = MakeViewModel(me: SampleTrip.budiID, service: service)
        let agusListening = Task { await agusPhone.Listen() }
        let budiListening = Task { await budiPhone.Listen() }
        defer {
            agusListening.cancel()
            budiListening.cancel()
        }
        try await WaitUntil { agusPhone.state != nil && budiPhone.state != nil }
        let budi = try #require(agusPhone.participants.first(where: { $0.id == SampleTrip.budiID }))

        await agusPhone.HandOverLead(to: budi)
        try await WaitUntil { budiPhone.isCurrentUserLeader && !agusPhone.isCurrentUserLeader }

        #expect(agusPhone.canStartTrip == false)
        #expect(agusPhone.showsKickSwipe == false)
        #expect(agusPhone.showsSetLeaderSwipe == false)
        #expect(budiPhone.canStartTrip == true)
        #expect(budiPhone.showsKickSwipe == true)
        #expect(budiPhone.showsSetLeaderSwipe == true)
        #expect(budiPhone.IsLeader(participant: budi) == true)
    }

    /// The save fails, for example without internet: the person reads the service's sentence, not
    /// "The operation couldn't be completed", and stays the leader.
    @Test func FailedHandOverShowsAReadableMessage() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        service.simulatedFailure = .noNetwork
        let state = SampleTrip.State(status: .lobby)
        let viewModel = MakeViewModel(me: SampleTrip.agusID, state: state, service: service)
        let budi = try #require(state.participants.first(where: { $0.id == SampleTrip.budiID }))

        await viewModel.HandOverLead(to: budi)

        #expect(viewModel.errorMessage == String(localized: TripServiceError.noNetwork.message))
        #expect(viewModel.isCurrentUserLeader == true)
    }

    /// The conditional write: this phone still thinks Agus leads, but the lead already moved to Citra. Handing it to
    /// Budi must fail with the conflict message and leave Citra as the only leader.
    @Test func HandOverFromAStaleLeaderIsRefused() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let staleState = SampleTrip.State(status: .lobby)
        let viewModel = MakeViewModel(me: SampleTrip.agusID, state: staleState, service: service)
        let budi = try #require(staleState.participants.first(where: { $0.id == SampleTrip.budiID }))
        try await service.SetLeader(SampleTrip.citraID, tripID: SampleTrip.tripID, replacing: SampleTrip.agusID)

        await viewModel.HandOverLead(to: budi)

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.trip.leaderParticipantID == SampleTrip.citraID)
        #expect(viewModel.errorMessage == String(localized: TripServiceError.conflict.message))
    }

    /// Every Trip Room alert shows the service's sentence for a failed call.
    @Test func ShowErrorUsesTheServiceMessage() {
        let viewModel = MakeViewModel(me: SampleTrip.agusID, state: SampleTrip.State(status: .lobby))

        viewModel.ShowError(TripServiceError.tripEnded)

        #expect(viewModel.errorMessage == String(localized: TripServiceError.tripEnded.message))
    }

    private func MakeViewModel(
        me participantID: UUID,
        state: TripState? = nil,
        service: InMemoryTripService? = nil
    ) -> TripRoomViewModel {
        TripRoomViewModel(
            tripService: service ?? SampleTrip.Service(status: .lobby, me: participantID),
            tripID: SampleTrip.tripID,
            myParticipantID: participantID,
            initialState: state
        )
    }

    private func WaitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<40 where !condition() {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(condition())
    }
}
