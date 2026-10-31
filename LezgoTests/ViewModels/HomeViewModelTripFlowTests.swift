//
//  HomeViewModelTripFlowTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 30/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Which screen Home opens as a trip moves on: the map for a late member (US-02), and the Trip Room again after a
/// New Destination (US-07).
@MainActor
struct HomeViewModelTripFlowTests {
    @Test("JoinTrip on a trip that already started opens the map for the late member (US-02)")
    func joinTripInProgressOpensMap() async {
        let fakeStorage = FakeActiveTripStorage()
        let service = SampleTrip.Service(status: .inTrip, me: UUID())
        let viewModel = HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: fakeStorage
        )

        let success = await viewModel.JoinTrip(roomCode: SampleTrip.roomCode, tripService: service)

        #expect(success == true)
        #expect(viewModel.activeMapSession?.state.trip.status == .inTrip)
        #expect(viewModel.activeTripSession == nil)
        #expect(fakeStorage.storedSummary?.status == .inTrip)
    }

    @Test("onTripJoined with a trip that already started opens the map, not the Trip Room (US-02)")
    func onTripJoinedInProgressOpensMap() {
        let fakeStorage = FakeActiveTripStorage()
        let viewModel = HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: fakeStorage
        )
        let session = TripSession(myParticipantID: SampleTrip.budiID, state: SampleTrip.State(status: .inTrip))

        viewModel.onTripJoined(session)

        #expect(viewModel.activeMapSession == session)
        #expect(viewModel.activeTripSession == nil)
        #expect(fakeStorage.storedSummary?.status == .inTrip)
    }

    @Test("Going back from the map to the Trip Room keeps the trip saved and opens the room (US-07)")
    func returnToTripRoomFromMap() async throws {
        let fakeStorage = FakeActiveTripStorage()
        let viewModel = HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: fakeStorage
        )
        let lobby = TripSession(myParticipantID: SampleTrip.budiID, state: SampleTrip.State(status: .lobby))
        fakeStorage.SaveActiveTrip(ActiveTripSummary.From(session: lobby))
        viewModel.activeMapSession = TripSession(
            myParticipantID: SampleTrip.budiID,
            state: SampleTrip.State(status: .inTrip)
        )

        viewModel.onReturnedToTripRoom(lobby)
        // The map's full-screen cover reports its dismissal too, which must not end the trip on this phone.
        viewModel.onMapSessionClosed()
        for _ in 0..<40 where viewModel.activeTripSession == nil {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(viewModel.activeMapSession == nil)
        #expect(viewModel.activeTripSession == lobby)
        #expect(fakeStorage.storedSummary?.status == .lobby)
        #expect(fakeStorage.clearCount == 0)
    }
}
