//
//  TripMapViewModelMyGPSTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 30/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The map follows this phone's own GPS, not the copy of it that comes back from the trip a moment later (#219).
struct TripMapViewModelMyGPSTests {
    let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
    let gps = MockLocationProvider()
    let navigator = MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())])

    /// A map whose sharer sends only once a minute, so within a test the trip never has this phone's new position:
    /// anything the map knows about it came straight from the GPS.
    private func MakeMap() -> TripMapViewModel {
        TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            tripService: service,
            navigator: navigator,
            streetNameService: MockStreetNameService(),
            locationSharer: LocationSharer(
                tripService: service,
                locationProvider: gps,
                tripID: SampleTrip.tripID,
                participantID: SampleTrip.budiID,
                interval: .seconds(60)
            )
        )
    }

    /// Opens the map, sends one GPS reading, waits for it to be handled, then closes the map.
    private func Drive(_ viewModel: TripMapViewModel, to coordinate: Coordinate) async throws {
        let open = Task { await viewModel.Start() }
        // The fake GPS drops readings sent before the map listens, which takes longer on a busy test machine, so
        // the reading is sent until it arrives.
        let reading = LocationReading(coordinate: coordinate, speedKmh: 40, recordedAt: .now)
        for _ in 0..<200 where viewModel.myReading != reading {
            gps.Send(reading)
            try await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(40))
        open.cancel()
        await open.value
    }

    @Test func MyPositionIsThePhonesGPSReading() async throws {
        let viewModel = MakeMap()

        try await Drive(viewModel, to: TripFixtures.pakuwonMall)

        #expect(viewModel.myCoordinate == TripFixtures.pakuwonMall)
    }

    @Test func GuidanceIsAskedFromThePhonesGPSReading() async throws {
        let viewModel = MakeMap()

        try await Drive(viewModel, to: TripFixtures.pakuwonMall)

        #expect(navigator.requestedPositions.last == TripFixtures.pakuwonMall)
        #expect(viewModel.guidance != nil)
    }

    @Test func MyCarInTheTripMovesWithThePhonesGPS() async throws {
        let viewModel = MakeMap()

        try await Drive(viewModel, to: TripFixtures.pakuwonMall)

        // Checkpoints, alerts and the reroute read the trip state, so this phone's car there is up to date too.
        let me = viewModel.state?.participants.first { $0.id == SampleTrip.budiID }
        #expect(me?.coordinate == TripFixtures.pakuwonMall)
    }

    @Test func MyCarIsTheLocationDotNotAPin() async throws {
        let viewModel = MakeMap()

        try await Drive(viewModel, to: TripFixtures.pakuwonMall)

        #expect(viewModel.showsMyLocationDot)
        #expect(viewModel.carPins.contains { $0.isMe } == false)
        #expect(viewModel.carPins.isEmpty == false)
    }

    @Test func WithoutGPSMyCarIsAPinFromTheTrip() async throws {
        // Previews and the simulated drive have no sharer: the trip is the only place this phone's car comes from.
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            tripService: service,
            navigator: navigator,
            streetNameService: MockStreetNameService()
        )
        try await service.UpdateLocation(
            LocationUpdate(
                coordinate: TripFixtures.ciputraWorld,
                speedKmh: 40,
                motionState: .driving,
                recordedAt: .now
            ),
            participantID: SampleTrip.budiID,
            tripID: SampleTrip.tripID
        )

        let open = Task { await viewModel.Start() }
        try await Task.sleep(for: .milliseconds(40))
        open.cancel()
        await open.value

        #expect(viewModel.showsMyLocationDot == false)
        #expect(viewModel.myCoordinate == TripFixtures.ciputraWorld)
        #expect(viewModel.carPins.contains { $0.isMe })
    }

    @Test func OtherCarsPointTheWayTheyDrive() async throws {
        let viewModel = MakeMap()
        try await service.UpdateLocation(
            LocationUpdate(
                coordinate: TripFixtures.ciputraWorld,
                speedKmh: 40,
                motionState: .driving,
                recordedAt: .now,
                course: 180
            ),
            participantID: SampleTrip.agusID,
            tripID: SampleTrip.tripID
        )

        try await Drive(viewModel, to: TripFixtures.pakuwonMall)

        #expect(viewModel.carPins.first { $0.id == SampleTrip.agusID }?.course == 180)
    }
}
