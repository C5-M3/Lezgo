import Foundation
import Testing
@testable import Lezgo

struct LocationSharerTests {
    let phones = TripPhones(.inMemory)
    let gps = MockLocationProvider()

    private func Reading(_ coordinate: Coordinate, speedKmh: Double = 40) -> LocationReading {
        LocationReading(coordinate: coordinate, speedKmh: speedKmh, recordedAt: .now)
    }

    /// Runs the sharer for `duration`, sending GPS readings at the start, then stops it like leaving the map.
    private func Share(
        as service: any TripService,
        in group: TripGroup,
        for duration: Duration,
        readings: [LocationReading]
    ) async -> LocationSharer {
        let sharer = LocationSharer(
            tripService: service,
            locationProvider: gps,
            tripID: group.tripID,
            participantID: group.budiID,
            interval: .milliseconds(10)
        )
        let run = Task { await sharer.Run() }
        try? await Task.sleep(for: .milliseconds(5))
        readings.forEach(gps.Send)
        try? await Task.sleep(for: duration)
        run.cancel()
        await run.value
        return sharer
    }

    @Test func LatestReadingIsShared() async throws {
        let group = try await phones.MakeGroupOnTheRoad()

        let sharer = await Share(
            as: phones.budi,
            in: group,
            for: .milliseconds(80),
            readings: [Reading(TripFixtures.tunjunganPlaza), Reading(TripFixtures.ciputraWorld)]
        )

        let budi = try #require(try await phones.Budi(in: group))
        #expect(budi.coordinate == TripFixtures.ciputraWorld)
        #expect(budi.motionState == .driving)
        #expect(sharer.sentCount > 0)
    }

    @Test func NothingIsSentBeforeTheFirstReading() async throws {
        let group = try await phones.MakeGroupOnTheRoad()

        let sharer = await Share(as: phones.budi, in: group, for: .milliseconds(60), readings: [])

        #expect(sharer.sentCount == 0)
        #expect(try await phones.Budi(in: group)?.coordinate == nil)
    }

    @Test func LastPositionIsSentAgainWithoutGpsSignal() async throws {
        let group = try await phones.MakeGroupOnTheRoad()

        let sharer = await Share(
            as: phones.budi,
            in: group,
            for: .milliseconds(100),
            readings: [Reading(TripFixtures.ciputraWorld)]
        )

        // One reading, but a send on every tick keeps `lastSeenAt` fresh so the car never looks offline.
        #expect(sharer.sentCount >= 3)
    }

    @Test func SendingContinuesAfterTheNetworkComesBack() async throws {
        let group = try await phones.MakeGroupOnTheRoad()
        let budi = try #require(phones.budi as? InMemoryTripService)
        budi.simulatedFailure = .noNetwork
        let sharer = LocationSharer(
            tripService: budi,
            locationProvider: gps,
            tripID: group.tripID,
            participantID: group.budiID,
            interval: .milliseconds(10)
        )
        let run = Task { await sharer.Run() }
        try await Task.sleep(for: .milliseconds(5))
        gps.Send(Reading(TripFixtures.ciputraWorld))
        try await Task.sleep(for: .milliseconds(40))
        let errorWhileOffline = sharer.lastError

        budi.simulatedFailure = nil
        try await Task.sleep(for: .milliseconds(40))
        run.cancel()
        await run.value

        #expect(errorWhileOffline == .noNetwork)
        #expect(sharer.lastError == nil)
        #expect(try await phones.Budi(in: group)?.coordinate == TripFixtures.ciputraWorld)
    }

    @Test func StoppingTheTaskStopsSharing() async throws {
        let group = try await phones.MakeGroupOnTheRoad()
        let sharer = await Share(
            as: phones.budi,
            in: group,
            for: .milliseconds(40),
            readings: [Reading(TripFixtures.ciputraWorld)]
        )
        let sentWhenStopped = sharer.sentCount

        try await Task.sleep(for: .milliseconds(50))

        #expect(sharer.sentCount == sentWhenStopped)
    }
}
