//
//  TripMapViewModelCarColorTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Every car on the map has its own robot color: yellow for the leader, then one color per member in join order.
struct TripMapViewModelCarColorTests {
    private typealias Fixtures = TripMapFixtures

    private func PinColors(cars: [Participant]) async -> [UUID: TripMapCarPin.CarColor] {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: [Fixtures.State(cars: cars)]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        return Dictionary(uniqueKeysWithValues: viewModel.carPins.map { ($0.id, $0.carColor) })
    }

    @Test func LeaderIsYellowAndMembersFollowInJoinOrder() async {
        let colors = await PinColors(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus"),
            Fixtures.Car(id: Fixtures.budiID, name: "Budi"),
            Fixtures.Car(id: Fixtures.citraID, name: "Citra")
        ])

        #expect(colors[Fixtures.agusID] == .yellow)
        #expect(colors[Fixtures.budiID] == .purple)
        #expect(colors[Fixtures.citraID] == .pink)
    }

    @Test func LeaderIsYellowWhereverTheLeaderIsInTheList() async {
        let colors = await PinColors(cars: [
            Fixtures.Car(id: Fixtures.budiID, name: "Budi"),
            Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        ])

        #expect(colors[Fixtures.agusID] == .yellow)
        #expect(colors[Fixtures.budiID] == .purple)
    }

    @Test func AMemberWithoutAPositionStillKeepsTheirPlaceInTheOrder() async {
        var budi = Fixtures.Car(id: Fixtures.budiID, name: "Budi")
        budi.coordinate = nil
        let colors = await PinColors(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus"),
            budi,
            Fixtures.Car(id: Fixtures.citraID, name: "Citra")
        ])

        #expect(colors[Fixtures.budiID] == nil)
        #expect(colors[Fixtures.citraID] == .pink)
    }

    @Test func ColorsRepeatWhenThereAreMoreMembersThanColors() {
        #expect(TripMapCarPin.CarColor.ForMember(atIndex: 0) == .purple)
        #expect(TripMapCarPin.CarColor.ForMember(atIndex: 3) == .green)
        #expect(TripMapCarPin.CarColor.ForMember(atIndex: 4) == .purple)
    }
}
