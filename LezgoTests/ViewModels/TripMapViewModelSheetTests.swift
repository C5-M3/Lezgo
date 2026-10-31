//
//  TripMapViewModelSheetTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// What the trip map's sheet lists when it is pulled up (#221). Budi, a member, uses this phone.
struct TripMapViewModelSheetTests {
    private typealias Fixtures = TripMapFixtures

    private func OpenMap(_ state: TripState = Fixtures.State()) async -> TripMapViewModel {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: [state]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        return viewModel
    }

    @Test func EveryCarIsListedWithTheLeaderFirst() async {
        let state = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.budiID, name: "Budi"),
            Fixtures.Car(id: Fixtures.citraID, name: "Citra"),
            Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        ])

        let viewModel = await OpenMap(state)

        #expect(viewModel.carStatuses.map(\.displayName) == ["Agus", "Budi", "Citra"])
    }

    @Test func ListedCarsSayWhatTheyAreDoing() async throws {
        let state = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus"),
            Fixtures.Car(id: Fixtures.budiID, name: "Budi", motionState: .stopped),
            Fixtures.Car(id: Fixtures.citraID, name: "Citra", lastSeenSecondsAgo: 300)
        ])

        let viewModel = await OpenMap(state)

        let activities = viewModel.carStatuses.map(\.activity)
        #expect(activities == [
            .driving(street: nil),
            .stopped(street: nil),
            .offline(lastSeen: .seconds(300))
        ])
    }

    @Test func ACarWithoutAPositionIsListedToo() async {
        // Someone who joined but has not sent a position yet is still in the trip.
        var waiting = Fixtures.Car(id: Fixtures.citraID, name: "Citra")
        waiting.coordinate = nil
        let state = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus"),
            Fixtures.Car(id: Fixtures.budiID, name: "Budi"),
            waiting
        ])

        let viewModel = await OpenMap(state)

        #expect(viewModel.carStatuses.map(\.displayName) == ["Agus", "Budi", "Citra"])
    }

    @Test func RoomCodeIsShownSoOthersCanJoinLate() async {
        let viewModel = await OpenMap()

        #expect(viewModel.roomCode == "897654")
    }

    @Test func NothingIsListedBeforeTheTripLoads() {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: []),
            navigator: MockTripMapNavigator(results: []),
            streetNameService: MockStreetNameService()
        )

        #expect(viewModel.carStatuses.isEmpty)
        #expect(viewModel.roomCode == nil)
    }
}
