//
//  TripMapViewModelConnectionTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// "Connection lost" on the trip map while this phone cannot send its position (#220).
struct TripMapViewModelConnectionTests {
    let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
    let gps = MockLocationProvider()

    private func MakeMap() -> TripMapViewModel {
        TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            locationSharer: LocationSharer(
                tripService: service,
                locationProvider: gps,
                tripID: SampleTrip.tripID,
                participantID: SampleTrip.budiID,
                interval: .milliseconds(10)
            )
        )
    }

    /// Sends GPS readings until the map has one, so the sharer has something to send.
    private func SendReading(to viewModel: TripMapViewModel) async throws {
        let reading = LocationReading(coordinate: TripFixtures.pakuwonMall, speedKmh: 40, recordedAt: .now)
        for _ in 0..<200 where viewModel.myReading != reading {
            gps.Send(reading)
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func NoNoticeWhileSendsWork() async throws {
        let viewModel = MakeMap()
        let open = Task { await viewModel.Start() }

        try await SendReading(to: viewModel)
        try await Task.sleep(for: .milliseconds(40))
        let isLost = viewModel.isConnectionLost
        open.cancel()
        await open.value

        #expect(isLost == false)
    }

    @Test func NoticeShowsWhileSendsFailAndHidesWhenTheyWorkAgain() async throws {
        let viewModel = MakeMap()
        let open = Task { await viewModel.Start() }
        try await SendReading(to: viewModel)

        service.simulatedFailure = .noNetwork
        try await Task.sleep(for: .milliseconds(40))
        let isLostWhileOffline = viewModel.isConnectionLost
        service.simulatedFailure = nil
        try await Task.sleep(for: .milliseconds(40))
        let isLostWhenBack = viewModel.isConnectionLost
        open.cancel()
        await open.value

        #expect(isLostWhileOffline)
        #expect(isLostWhenBack == false)
    }

    @Test func NoNoticeWithoutASharer() {
        // Previews and the simulated drive send nothing, so they never lose a connection.
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            tripService: service,
            navigator: MockTripMapNavigator(results: []),
            streetNameService: MockStreetNameService()
        )

        #expect(viewModel.isConnectionLost == false)
    }

    @Test func MapSaysWhenPreciseLocationIsOff() async throws {
        let viewModel = MakeMap()
        let open = Task { await viewModel.Start() }
        var rough = LocationReading(coordinate: TripFixtures.pakuwonMall, speedKmh: 40, recordedAt: .now)
        rough.isPrecise = false
        gps.Send(rough)
        for _ in 0..<200 where viewModel.isLocationImprecise == false {
            try await Task.sleep(for: .milliseconds(10))
        }
        open.cancel()
        await open.value

        #expect(viewModel.isLocationImprecise)
        // A reading kilometres wide would put this car on the wrong street, so the map does not use it.
        #expect(viewModel.myReading == nil)
    }
}
