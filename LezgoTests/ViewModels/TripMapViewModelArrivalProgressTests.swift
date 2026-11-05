//
//  TripMapViewModelArrivalProgressTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The top card once this phone's car has arrived: a robot per arrived car, up to five, and the count.
struct TripMapViewModelArrivalProgressTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(states: [TripState]) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: states),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
    }

    private func Near(_ id: UUID, _ name: String, metres: Double = 5) -> Participant {
        Fixtures.CarNearDestination(id: id, name: name, metres: metres)
    }

    /// `count` members beyond Agus and Budi, all at the destination.
    private func ExtraCars(_ count: Int) -> [Participant] {
        (0..<count).map { Near(UUID(), "Car \($0)") }
    }

    @Test func NoProgressBeforeMyCarArrives() async {
        let viewModel = MakeViewModel(states: [Fixtures.State(cars: [
            Near(Fixtures.agusID, "Agus"),
            Near(Fixtures.budiID, "Budi", metres: 500)
        ])])

        await viewModel.Start()

        #expect(viewModel.arrivalProgress == nil)
    }

    @Test func CountsTheArrivedCarsOfTheWholeGroup() async throws {
        let viewModel = MakeViewModel(states: [Fixtures.State(cars: [
            Near(Fixtures.agusID, "Agus"),
            Near(Fixtures.budiID, "Budi"),
            Near(Fixtures.citraID, "Citra", metres: 500)
        ])])

        await viewModel.Start()

        let progress = try #require(viewModel.arrivalProgress)
        #expect(progress.arrivedCount == 2)
        #expect(progress.totalCount == 3)
    }

    @Test func RobotsKeepArrivalOrderAndEachCarsColor() async throws {
        let viewModel = MakeViewModel(states: [
            Fixtures.State(cars: [
                Near(Fixtures.agusID, "Agus", metres: 500),
                Near(Fixtures.budiID, "Budi")
            ]),
            Fixtures.State(cars: [
                Near(Fixtures.agusID, "Agus"),
                Near(Fixtures.budiID, "Budi")
            ])
        ])

        await viewModel.Start()

        let progress = try #require(viewModel.arrivalProgress)
        #expect(progress.robots.map(\.id) == [Fixtures.budiID, Fixtures.agusID])
        #expect(progress.robots.map(\.carColor) == [.purple, .yellow])
    }

    @Test func AtMostFiveRobotsShowWhileTheCountKeepsGoing() async throws {
        let cars = [Near(Fixtures.agusID, "Agus"), Near(Fixtures.budiID, "Budi")] + ExtraCars(5)
        let viewModel = MakeViewModel(states: [Fixtures.State(cars: cars)])

        await viewModel.Start()

        let progress = try #require(viewModel.arrivalProgress)
        #expect(progress.robots.count == TripMapArrivalProgress.maxRobots)
        #expect(progress.arrivedCount == 7)
        #expect(progress.totalCount == 7)
        #expect(progress.countText == "7/7")
    }

    @Test func TheFirstFiveToArriveAreTheOnesShown() async throws {
        let extras = ExtraCars(5)
        let viewModel = MakeViewModel(states: [Fixtures.State(cars: [Near(Fixtures.agusID, "Agus"), Near(Fixtures.budiID, "Budi")] + extras)])

        await viewModel.Start()

        let progress = try #require(viewModel.arrivalProgress)
        #expect(progress.robots.map(\.id).contains(extras[4].id) == false)
    }
}
