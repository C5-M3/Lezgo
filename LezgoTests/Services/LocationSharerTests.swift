//
//  LocationSharerTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

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
    ///
    /// With `until`, it runs until that is true instead (at most 2 seconds): with every suite running at once, the
    /// sharer's 10 ms timer may only get a turn or two within a fixed wait.
    private func Share(
        as service: any TripService,
        in group: TripGroup,
        for duration: Duration,
        readings: [LocationReading],
        until isDone: ((LocationSharer) async -> Bool)? = nil
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
        if let isDone {
            for _ in 0..<200 where await isDone(sharer) == false {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
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
            readings: [Reading(TripFixtures.tunjunganPlaza), Reading(TripFixtures.ciputraWorld)],
            until: { _ in (try? await phones.Budi(in: group)?.coordinate) == TripFixtures.ciputraWorld }
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
            readings: [Reading(TripFixtures.ciputraWorld)],
            until: { $0.sentCount >= 3 }
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
        gps.Send(Reading(TripFixtures.ciputraWorld))
        // Waits for each result rather than a fixed time: with every suite running at once it can take longer.
        for _ in 0..<200 where sharer.lastError == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        let errorWhileOffline = sharer.lastError

        budi.simulatedFailure = nil
        for _ in 0..<200 where try await phones.Budi(in: group)?.coordinate != TripFixtures.ciputraWorld {
            try await Task.sleep(for: .milliseconds(10))
        }
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

    @Test func HeadingIsShared() async throws {
        let group = try await phones.MakeGroupOnTheRoad()
        var reading = Reading(TripFixtures.ciputraWorld)
        reading.course = 90

        _ = await Share(
            as: phones.budi,
            in: group,
            for: .milliseconds(40),
            readings: [reading],
            until: { _ in (try? await phones.Budi(in: group)?.course) == 90 }
        )

        #expect(try await phones.Budi(in: group)?.course == 90)
    }

    @Test func OlderReadingDoesNotReplaceANewerOne() async throws {
        let group = try await phones.MakeGroupOnTheRoad()
        let newer = Reading(TripFixtures.ciputraWorld)
        var older = Reading(TripFixtures.tunjunganPlaza)
        older.recordedAt = newer.recordedAt.addingTimeInterval(-10)

        // After two sends, an older reading that wrongly replaced the newer one would have been sent.
        _ = await Share(
            as: phones.budi,
            in: group,
            for: .milliseconds(40),
            readings: [newer, older],
            until: { $0.sentCount >= 2 }
        )

        #expect(try await phones.Budi(in: group)?.coordinate == TripFixtures.ciputraWorld)
    }

    @Test func ImpreciseReadingIsNotSharedButReported() async throws {
        let group = try await phones.MakeGroupOnTheRoad()
        var rough = Reading(TripFixtures.ciputraWorld)
        rough.isPrecise = false

        let sharer = await Share(
            as: phones.budi,
            in: group,
            for: .milliseconds(40),
            readings: [rough],
            until: { $0.isLocationImprecise }
        )

        #expect(sharer.isLocationImprecise)
        #expect(try await phones.Budi(in: group)?.coordinate == nil)
    }

    @Test func PreciseReadingClearsTheReport() async throws {
        let group = try await phones.MakeGroupOnTheRoad()
        var rough = Reading(TripFixtures.tunjunganPlaza)
        rough.isPrecise = false

        let sharer = await Share(
            as: phones.budi,
            in: group,
            for: .milliseconds(40),
            readings: [rough, Reading(TripFixtures.ciputraWorld)],
            until: { _ in (try? await phones.Budi(in: group)?.coordinate) == TripFixtures.ciputraWorld }
        )

        #expect(sharer.isLocationImprecise == false)
        #expect(try await phones.Budi(in: group)?.coordinate == TripFixtures.ciputraWorld)
    }
}
