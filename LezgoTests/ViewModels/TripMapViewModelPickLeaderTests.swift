//
//  TripMapViewModelPickLeaderTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Picking a new leader after the leader has been offline for 5 minutes (`specs/UserStories.md` → US-06).
struct TripMapViewModelPickLeaderTests {
    private func MakeViewModel(service: InMemoryTripService, me: UUID = SampleTrip.budiID) -> TripMapViewModel {
        TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: me,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())]),
            streetNameService: MockStreetNameService()
        )
    }

    @Test func PickingSavesTheNewLeader() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let viewModel = MakeViewModel(service: service)
        let open = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(50))
        viewModel.OpenLeaderPicker()
        #expect(viewModel.notices.isPickingLeader)

        await viewModel.PickLeader(SampleTrip.citraID)

        let state = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(state.trip.leaderParticipantID == SampleTrip.citraID)
        #expect(viewModel.notices.isPickingLeader == false)
        open.cancel()
    }

    @Test func WhenSomeoneElsePickedFirstThePickerClosesWithAMessage() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let viewModel = MakeViewModel(service: service)
        let open = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(50))
        viewModel.OpenLeaderPicker()
        // The picker still believes Agus leads; another phone has just replaced him with Citra.
        let staleLeader = try #require(viewModel.state?.trip.leaderParticipantID)
        try await service.SetLeader(SampleTrip.citraID, tripID: SampleTrip.tripID, replacing: staleLeader)

        await viewModel.PickLeader(SampleTrip.budiID, replacing: staleLeader)

        #expect(viewModel.leaveErrorMessage != nil)
        #expect(viewModel.notices.isPickingLeader == false)
        open.cancel()
    }
}
