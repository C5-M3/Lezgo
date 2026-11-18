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

    private func MakeViewModel(cars: [Participant], currentWaypointIndex: Int = 1) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: [Fixtures.State(cars: cars, currentWaypointIndex: currentWaypointIndex)]),
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

    /// The track runs from the stop the group left to the next stop, here the checkpoint.
    @Test func TheTrackRunsFromTheStartToTheNextCheckpoint() async throws {
        let halfway = Coordinate(
            latitude: (Fixtures.startPoint.coordinate.latitude + Fixtures.checkpoint.coordinate.latitude) / 2,
            longitude: (Fixtures.startPoint.coordinate.longitude + Fixtures.checkpoint.coordinate.longitude) / 2
        )
        let viewModel = MakeViewModel(cars: [
            Car(Fixtures.agusID, name: "Agus", at: Fixtures.startPoint.coordinate),
            Car(Fixtures.budiID, name: "Budi", at: halfway),
            Car(Fixtures.citraID, name: "Citra", at: Fixtures.checkpoint.coordinate)
        ])
        await viewModel.Start()

        let progress = try #require(viewModel.routeProgress)

        #expect(try #require(progress.cars.first { $0.id == Fixtures.agusID }).fraction < 0.01)
        #expect(abs(try #require(progress.cars.first { $0.id == Fixtures.budiID }).fraction - 0.5) < 0.05)
        #expect(try #require(progress.cars.first { $0.id == Fixtures.citraID }).fraction > 0.99)
    }

    /// Once the checkpoint is passed, the track starts again from it and ends at the destination.
    @Test func AfterTheCheckpointTheTrackRunsToTheDestination() async throws {
        let viewModel = MakeViewModel(
            cars: [
                Car(Fixtures.agusID, name: "Agus", at: Fixtures.checkpoint.coordinate),
                Car(Fixtures.budiID, name: "Budi", at: Fixtures.destination.coordinate),
                Car(Fixtures.citraID, name: "Citra", at: Fixtures.startPoint.coordinate)
            ],
            currentWaypointIndex: 2
        )
        await viewModel.Start()

        let progress = try #require(viewModel.routeProgress)

        #expect(try #require(progress.cars.first { $0.id == Fixtures.agusID }).fraction < 0.01)
        #expect(try #require(progress.cars.first { $0.id == Fixtures.budiID }).fraction > 0.99)
        // A car still behind the checkpoint waits at the start of the track.
        #expect(try #require(progress.cars.first { $0.id == Fixtures.citraID }).fraction == 0)
    }

    @Test func TheLeadIsTheCarFurthestAlongTheTrack() async throws {
        let viewModel = MakeViewModel(cars: [
            Car(Fixtures.agusID, name: "Agus", at: Fixtures.startPoint.coordinate),
            Car(Fixtures.budiID, name: "Budi", at: Fixtures.checkpoint.coordinate)
        ])
        await viewModel.Start()

        let progress = try #require(viewModel.routeProgress)
        let budi = try #require(progress.cars.first { $0.id == Fixtures.budiID })

        #expect(progress.leadFraction == budi.fraction)
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
