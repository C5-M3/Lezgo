//
//  TripMapViewModelNewDestinationTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 30/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// "New Destination" after arriving, and every phone going back to the Trip Room (`specs/UserStories.md` → US-07,
/// "New Destination").
struct TripMapViewModelNewDestinationTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(
        me: UUID,
        service: MockTripService,
        storage: FakeActiveTripStorage = FakeActiveTripStorage()
    ) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            activeTripStorage: storage,
            clock: { Fixtures.now }
        )
    }

    private func ArrivedState() -> TripState {
        Fixtures.State(cars: [
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: 5),
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10)
        ])
    }

    @Test func LeaderOpensThePlannerStartingAtTheOldDestination() async throws {
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: MockTripService(states: [ArrivedState()]))
        await viewModel.Start()

        viewModel.RequestNewDestination()

        let planner = try #require(viewModel.editRoute)
        #expect(planner.purpose == .newDestination)
        #expect(planner.startingWaypoints.map(\.kind) == [.start])
        #expect(planner.startingWaypoints.map(\.name) == ["Pakuwon mall"])
        #expect(planner.startingWaypoints.first?.coordinate == Fixtures.destination.coordinate)
    }

    @Test func MemberCannotPlanANewDestination() async {
        let viewModel = MakeViewModel(me: Fixtures.budiID, service: MockTripService(states: [ArrivedState()]))
        await viewModel.Start()

        viewModel.RequestNewDestination()

        #expect(viewModel.editRoute == nil)
    }

    @Test(arguments: [Fixtures.agusID, Fixtures.budiID])
    func TripBackInTheLobbyTakesEveryPhoneToTheTripRoom(me: UUID) async throws {
        let storage = FakeActiveTripStorage()
        let lobby = Fixtures.State(status: .lobby, currentWaypointIndex: 0)
        let viewModel = MakeViewModel(
            me: me,
            service: MockTripService(states: [ArrivedState(), lobby]),
            storage: storage
        )

        await viewModel.Start()

        #expect(viewModel.closeReason == .backToTripRoom)
        let session = try #require(viewModel.tripRoomSession)
        #expect(session.myParticipantID == me)
        #expect(session.state.trip.status == .lobby)
        #expect(storage.storedSummary?.status == .lobby)
        #expect(storage.clearCount == 0)
    }

    @Test func PlannerClosesWhenTheTripGoesBackToTheLobby() async {
        let lobby = Fixtures.State(status: .lobby, currentWaypointIndex: 0)
        let service = MockTripService(states: [ArrivedState(), lobby])
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: service)
        service.beforeEachState = { index in
            if index == 1 { viewModel.RequestNewDestination() }
        }

        await viewModel.Start()

        #expect(viewModel.editRoute == nil)
    }
}
