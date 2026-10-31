//
//  TripMapViewModelSharingTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Sharing this phone's position while the trip map is open (#170).
struct TripMapViewModelSharingTests {
    @Test func OpenMapSharesMyLocation() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let gps = MockLocationProvider()
        let sharer = LocationSharer(
            tripService: service,
            locationProvider: gps,
            tripID: SampleTrip.tripID,
            participantID: SampleTrip.budiID,
            interval: .milliseconds(10)
        )
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            locationSharer: sharer
        )

        let open = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(10))
        gps.Send(LocationReading(coordinate: TripFixtures.pakuwonMall, speedKmh: 30, recordedAt: .now))
        // Waits for the send rather than a fixed time: with every suite running at once it can take longer.
        for _ in 0..<200 where try await MyCoordinate(in: service) != TripFixtures.pakuwonMall {
            try await Task.sleep(for: .milliseconds(10))
        }
        open.cancel()
        await open.value

        #expect(sharer.sentCount > 0)
        let participants = try await service.FetchTrip(tripID: SampleTrip.tripID).participants
        let budi = participants.first { $0.id == SampleTrip.budiID }
        #expect(budi?.coordinate == TripFixtures.pakuwonMall)
    }

    private func MyCoordinate(in service: InMemoryTripService) async throws -> Coordinate? {
        try await service.FetchTrip(tripID: SampleTrip.tripID).participants
            .first { $0.id == SampleTrip.budiID }?.coordinate
    }

    @Test func LeavingTheMapStopsSharing() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let gps = MockLocationProvider()
        let sharer = LocationSharer(
            tripService: service,
            locationProvider: gps,
            tripID: SampleTrip.tripID,
            participantID: SampleTrip.budiID,
            interval: .milliseconds(10)
        )
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            locationSharer: sharer
        )
        let open = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(10))
        gps.Send(LocationReading(coordinate: TripFixtures.pakuwonMall, speedKmh: 30, recordedAt: .now))
        try await Task.sleep(for: .milliseconds(40))

        open.cancel()
        await open.value
        let sentWhenClosed = sharer.sentCount
        try await Task.sleep(for: .milliseconds(40))

        #expect(sharer.sentCount == sentWhenClosed)
    }
}
