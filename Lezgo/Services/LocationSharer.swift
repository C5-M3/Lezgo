//
//  LocationSharer.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation

/// Sends this phone's position to the trip once per `interval` while it runs (#170).
///
/// Readings arrive whenever the GPS has one; the latest is sent on a fixed one-second rate, which kept CloudKit
/// within the 2-second target and its limits in the load check (#69). While the GPS has no signal, the last known
/// position is sent again, so `lastSeenAt` stays fresh and the car does not look offline. Failed sends are retried
/// on the next tick.
@Observable
final class LocationSharer {
    /// The last send's error, or `nil` once a send works again.
    private(set) var lastError: TripServiceError?
    private(set) var sentCount = 0

    private var latest: LocationReading?
    private var detector = MotionStateDetector()

    private let tripService: any TripService
    private let locationProvider: any LocationProvider
    private let tripID: UUID
    private let participantID: UUID
    private let interval: Duration
    private let clock: () -> Date

    init(
        tripService: any TripService,
        locationProvider: any LocationProvider,
        tripID: UUID,
        participantID: UUID,
        interval: Duration = .seconds(1),
        clock: @escaping () -> Date = { .now }
    ) {
        self.tripService = tripService
        self.locationProvider = locationProvider
        self.tripID = tripID
        self.participantID = participantID
        self.interval = interval
        self.clock = clock
    }

    /// Shares the position until the task is cancelled, for example when the trip ends or this person leaves.
    /// - Parameter echo: also gets every reading as it arrives, so the map can show this phone's car without
    ///   waiting for the trip to send it back.
    func Run(echoingTo echo: AsyncStream<LocationReading>.Continuation? = nil) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.ReadGPS(echoingTo: echo) }
            group.addTask { await self.SendOnSchedule() }
        }
    }

    /// Keeps the latest reading and the motion state up to date as readings arrive.
    private func ReadGPS(echoingTo echo: AsyncStream<LocationReading>.Continuation?) async {
        for await reading in locationProvider.Readings() {
            latest = reading
            echo?.yield(reading)
            _ = detector.Update(speedKmh: reading.speedKmh, at: reading.recordedAt)
        }
    }

    /// Sends the latest reading at a fixed rate: a slow send shortens the wait instead of adding to it.
    private func SendOnSchedule() async {
        let ticker = ContinuousClock()
        var deadline = ticker.now
        while Task.isCancelled == false {
            await SendLatest()
            deadline = max(deadline.advanced(by: interval), ticker.now)
            try? await Task.sleep(until: deadline, clock: ticker)
        }
    }

    private func SendLatest() async {
        guard let latest else { return }
        let update = LocationUpdate(
            coordinate: latest.coordinate,
            speedKmh: latest.speedKmh,
            motionState: detector.state,
            recordedAt: clock()
        )
        do {
            try await tripService.UpdateLocation(update, participantID: participantID, tripID: tripID)
            sentCount += 1
            lastError = nil
        } catch {
            lastError = error as? TripServiceError ?? .noNetwork
        }
    }
}
