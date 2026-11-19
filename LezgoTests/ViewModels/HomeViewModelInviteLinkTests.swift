//
//  HomeViewModelInviteLinkTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 19/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// An invite link tapped while a trip is open on screen must not open Join Trip behind the trip
/// (`specs/UserStories.md` → US-02, US-03).
@MainActor
struct HomeViewModelInviteLinkTests {
    private func MakeViewModel() -> HomeViewModel {
        HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: FakeActiveTripStorage()
        )
    }

    private func MakeSession() -> TripSession {
        TripSession(myParticipantID: TripFixtures.budiID, state: TripMapFixtures.State())
    }

    @Test func InviteLinkIsIgnoredWhileTheTripRoomIsOpen() throws {
        let viewModel = MakeViewModel()
        viewModel.activeTripSession = MakeSession()
        let url = try #require(URL(string: "lezgo://join?code=897654"))

        viewModel.OpenInviteLink(url)

        #expect(viewModel.inviteRoomCode == nil)
    }

    @Test func InviteLinkIsIgnoredWhileTheTripMapIsOpen() throws {
        let viewModel = MakeViewModel()
        viewModel.activeMapSession = MakeSession()
        let url = try #require(URL(string: "lezgo://join?code=897654"))

        viewModel.OpenInviteLink(url)

        #expect(viewModel.inviteRoomCode == nil)
    }

    @Test func InviteLinkStillOpensJoinTripWithNoTripOpen() throws {
        let viewModel = MakeViewModel()
        let url = try #require(URL(string: "lezgo://join?code=897654"))

        viewModel.OpenInviteLink(url)

        #expect(viewModel.inviteRoomCode == "897654")
    }
}
