//
//  TripMapViewModelCarCardTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// What the car status card needs besides the status: which car it is, and the robot that drives it.
struct TripMapViewModelCarCardTests {
    private typealias Fixtures = TripMapFixtures

    @Test func TheCardKnowsTheCarAndItsRobot() async throws {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: [Fixtures.State(cars: [
                Fixtures.Car(id: Fixtures.agusID, name: "Agus"),
                Fixtures.Car(id: Fixtures.budiID, name: "Budi")
            ])]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)

        let status = try #require(viewModel.selectedCarStatus)
        #expect(status.carDescription == "Car of Budi")
        #expect(status.carColor == .purple)
    }

    @Test func AnOfflineCarKeepsItsDescriptionAndRobot() async throws {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: [Fixtures.State(cars: [
                Fixtures.Car(id: Fixtures.agusID, name: "Agus"),
                Fixtures.Car(id: Fixtures.budiID, name: "Budi", lastSeenSecondsAgo: 300)
            ])]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)

        let status = try #require(viewModel.selectedCarStatus)
        #expect(status.carDescription == "Car of Budi")
        #expect(status.carColor == .purple)
    }
}
