//
//  TripMapViewModelCarNameTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Cars without a typed name are called "Leader", "Car 2", "Car 3" on the map, never "Member 1d9d".
struct TripMapViewModelCarNameTests {
    private typealias Fixtures = TripMapFixtures

    @Test func PinsAndTheTappedCarUseTheAutomaticNames() async throws {
        let state = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: ""),
            Fixtures.Car(id: Fixtures.budiID, name: ""),
            Fixtures.Car(id: Fixtures.citraID, name: "")
        ])
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: [state]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.citraID)

        #expect(viewModel.carPins.map(\.displayName) == ["Leader", "Car 2", "Car 3"])
        #expect(viewModel.selectedCarStatus?.displayName == "Car 3")
    }
}
