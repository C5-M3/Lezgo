//
//  TripMapViewModelRouteProgressTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 18/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The track on the On the Go card: where each car is between the start and the end of the route (ADR 0034).
struct TripMapViewModelRouteProgressTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(cars: [Participant]) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: [Fixtures.State(cars: cars)]),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
    }

    private func Car(
        _ id: UUID,
        name: String,
        at coordinate: Coordinate,
        lastSeenSecondsAgo: Double = 1
    ) -> Participant {
        var car = Fixtures.Car(id: id, name: name, lastSeenSecondsAgo: lastSeenSecondsAgo)
        car.coordinate = coordinate
        return car
    }

    @Test func NoTrackBeforeTheTripIsKnown() {
        #expect(MakeViewModel(cars: []).routeProgress == nil)
    }

    @Test func ACarAtTheStartIsAtZeroAndACarAtTheEndIsAtOne() async throws {
        let viewModel = MakeViewModel(cars: [
            Car(Fixtures.agusID, name: "Agus", at: Fixtures.startPoint.coordinate),
            Car(Fixtures.budiID, name: "Budi", at: Fixtures.destination.coordinate)
        ])
        await viewModel.Start()

        let progress = try #require(viewModel.routeProgress)

        #expect(try #require(progress.cars.first { $0.id == Fixtures.agusID }).fraction < 0.01)
        #expect(try #require(progress.cars.first { $0.id == Fixtures.budiID }).fraction > 0.99)
    }

    @Test func TheLeadIsTheCarFurthestAlongTheRoute() async throws {
        let viewModel = MakeViewModel(cars: [
            Car(Fixtures.agusID, name: "Agus", at: Fixtures.startPoint.coordinate),
            Car(Fixtures.budiID, name: "Budi", at: Fixtures.checkpoint.coordinate)
        ])
        await viewModel.Start()

        let progress = try #require(viewModel.routeProgress)
        let budi = try #require(progress.cars.first { $0.id == Fixtures.budiID })

        #expect(progress.leadFraction == budi.fraction)
        #expect(budi.fraction > 0.01 && budi.fraction < 0.99)
    }

    @Test func AnOfflineCarIsLeftOutOfTheTrack() async throws {
        let viewModel = MakeViewModel(cars: [
            Car(Fixtures.agusID, name: "Agus", at: Fixtures.startPoint.coordinate),
            Car(Fixtures.budiID, name: "Budi", at: Fixtures.checkpoint.coordinate, lastSeenSecondsAgo: 600)
        ])
        await viewModel.Start()

        let progress = try #require(viewModel.routeProgress)

        #expect(progress.cars.map(\.id) == [Fixtures.agusID])
    }
}
