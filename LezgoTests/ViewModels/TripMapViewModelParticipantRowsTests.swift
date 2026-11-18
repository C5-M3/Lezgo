//
//  TripMapViewModelParticipantRowsTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 18/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The On the Go list the phone shows while CarPlay is connected (ADR 0034). Agus, the leader, uses this phone.
struct TripMapViewModelParticipantRowsTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(
        me: UUID = Fixtures.agusID,
        state: TripState = Fixtures.State(currentWaypointIndex: 2),
        navigator: MockTripMapNavigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance(minutesLeft: 50))])
    ) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: MockTripService(states: [state]),
            navigator: navigator,
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
    }

    @Test func NoRowsBeforeTheTripIsKnown() {
        #expect(MakeViewModel().participantRows.isEmpty)
    }

    @Test func EveryParticipantHasARowInTripOrder() async {
        let viewModel = MakeViewModel()

        await viewModel.Start()

        #expect(viewModel.participantRows.map(\.status.displayName) == ["Agus", "Budi", "Citra"])
    }

    /// As in the hi-fi, the phone's own car is first and the others follow in the order of the trip.
    @Test func MyOwnCarIsFirstAndTheOthersFollowInTripOrder() async {
        let viewModel = MakeViewModel(me: Fixtures.budiID)

        await viewModel.Start()

        #expect(viewModel.participantRows.map(\.status.displayName) == ["Budi", "Agus", "Citra"])
    }

    @Test func OnlyMyOwnRowIsMarkedAsMine() async {
        let viewModel = MakeViewModel()

        await viewModel.Start()

        #expect(viewModel.participantRows.filter(\.isMe).map(\.id) == [Fixtures.agusID])
    }

    @Test func RefreshingLooksUpEveryCarsStreetAndArrivalTime() async throws {
        let viewModel = MakeViewModel()
        await viewModel.Start()

        await viewModel.RefreshAllCars()

        let budi = try #require(viewModel.participantRows.first { $0.id == Fixtures.budiID })
        #expect(budi.status.statusLine == "Driving at Ahmad Yani Street")
        #expect(budi.timeToDestination == .seconds(50 * 60))
        let agus = try #require(viewModel.participantRows.first { $0.id == Fixtures.agusID })
        #expect(agus.timeToDestination == .seconds(50 * 60))
    }

    @Test func AnOfflineCarHasNoArrivalTime() async throws {
        let state = Fixtures.State(
            cars: [
                Fixtures.Car(id: Fixtures.agusID, name: "Agus", latitude: -7.2650),
                Fixtures.Car(id: Fixtures.budiID, name: "Budi", lastSeenSecondsAgo: 600)
            ],
            currentWaypointIndex: 2
        )
        let viewModel = MakeViewModel(state: state)
        await viewModel.Start()

        await viewModel.RefreshAllCars()

        let budi = try #require(viewModel.participantRows.first { $0.id == Fixtures.budiID })
        #expect(budi.timeToDestination == nil)
    }

    @Test func TheTimeToTheNextStopIsMyCars() async {
        let navigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance(minutesLeft: 50))])
        navigator.timeToPointResult = .success(.seconds(12 * 60))
        let viewModel = MakeViewModel(state: Fixtures.State(), navigator: navigator)
        await viewModel.Start()

        await viewModel.RefreshAllCars()

        #expect(viewModel.timeToNextStop == .seconds(12 * 60))
    }

    @Test func NoTimeToTheNextStopBeforeTheFirstLookup() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()

        #expect(viewModel.timeToNextStop == nil)
    }

    /// The list opens while the trip is still loading: the cars are looked up as soon as the trip is there, not
    /// after the next 30-second round.
    @Test func TrackingStartedBeforeTheTripLoadsLooksUpTheCarsAssoonAsItDoes() async throws {
        let viewModel = MakeViewModel()
        let tracking = Task { await viewModel.TrackAllCars() }
        defer { tracking.cancel() }

        await viewModel.Start()
        for _ in 0..<50 where viewModel.timeToNextStop == nil {
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(viewModel.timeToNextStop != nil)
    }
}
