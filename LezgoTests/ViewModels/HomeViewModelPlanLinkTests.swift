//
//  HomeViewModelPlanLinkTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// "Create a trip" from Siri opens Home with `lezgo://plan?to=Malang` (`specs/UserStories.md` → US-08).
@MainActor
struct HomeViewModelPlanLinkTests {
    private func MakeViewModel() -> HomeViewModel {
        // An empty storage: the simulator's saved draft from another test must not count as a trip here.
        HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: FakeActiveTripStorage()
        )
    }

    @Test func PlanLinkAsksToPlanATripToThePlace() throws {
        let viewModel = MakeViewModel()
        let url = try #require(URL(string: "lezgo://plan?to=Malang"))

        viewModel.OpenPlanLink(url)

        #expect(viewModel.plannedDestination == "Malang")
    }

    @Test func PlanLinkIsIgnoredWhileATripIsOpen() throws {
        let viewModel = MakeViewModel()
        viewModel.activeTripSession = TripSession(myParticipantID: TripFixtures.budiID, state: TripMapFixtures.State())
        let url = try #require(URL(string: "lezgo://plan?to=Malang"))

        viewModel.OpenPlanLink(url)

        #expect(viewModel.plannedDestination == nil)
    }

    @Test func PlanLinkIsIgnoredWithADraftTrip() throws {
        let session = TripSession(myParticipantID: TripFixtures.budiID, state: TripMapFixtures.State())
        let viewModel = HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: FakeActiveTripStorage(initial: .From(session: session))
        )
        let url = try #require(URL(string: "lezgo://plan?to=Malang"))

        viewModel.OpenPlanLink(url)

        #expect(viewModel.plannedDestination == nil)
    }

    @Test func InviteLinkPlansNothing() throws {
        let viewModel = MakeViewModel()
        let url = try #require(URL(string: "lezgo://join?code=897654"))

        viewModel.OpenPlanLink(url)

        #expect(viewModel.plannedDestination == nil)
    }
}
