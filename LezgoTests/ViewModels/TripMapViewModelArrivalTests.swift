//
//  TripMapViewModelArrivalTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The arrival card on the trip map (`specs/UserStories.md` → US-07, "Arrive").
struct TripMapViewModelArrivalTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(me: UUID, states: [TripState]) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: MockTripService(states: states),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            clock: { Fixtures.now }
        )
    }

    private func ArrivedState(citraMetres: Double) -> TripState {
        Fixtures.State(cars: [
            Fixtures.CarNearDestination(id: Fixtures.agusID, name: "Agus", metres: 5),
            Fixtures.CarNearDestination(id: Fixtures.budiID, name: "Budi", metres: 10),
            Fixtures.CarNearDestination(id: Fixtures.citraID, name: "Citra", metres: citraMetres)
        ])
    }

    @Test func NoArrivalCardOnTheWay() async {
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [Fixtures.State()])

        await viewModel.Start()

        #expect(viewModel.arrivalCard == nil)
    }

    @Test func MemberWhoArrivedFirstWaitsForEveryone() async {
        let viewModel = MakeViewModel(me: Fixtures.budiID, states: [ArrivedState(citraMetres: 500)])

        await viewModel.Start()

        #expect(viewModel.arrivalCard == .waitingForEveryone)
    }

    @Test func LeaderWhoArrivedBeforeEveryoneWaitsToo() async {
        let viewModel = MakeViewModel(me: Fixtures.agusID, states: [ArrivedState(citraMetres: 500)])

        await viewModel.Start()

        #expect(viewModel.arrivalCard == .waitingForEveryone)
        #expect(viewModel.isLeader)
    }

    @Test func EveryoneArrivedCard() async {
        let viewModel = MakeViewModel(me: Fixtures.agusID, states: [ArrivedState(citraMetres: 10)])

        await viewModel.Start()

        #expect(viewModel.arrivalCard == .everyoneArrived)
    }

    @Test func CardChangesWhenTheLastCarArrives() async {
        let viewModel = MakeViewModel(
            me: Fixtures.budiID,
            states: [ArrivedState(citraMetres: 500), ArrivedState(citraMetres: 10)]
        )

        await viewModel.Start()

        #expect(viewModel.arrivalCard == .everyoneArrived)
    }
}
