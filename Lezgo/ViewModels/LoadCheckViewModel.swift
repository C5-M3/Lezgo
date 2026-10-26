#if DEBUG
import CloudKit
import Foundation
import Observation

/// Runs a CloudKit load check (#69) from one phone: several simulated cars, each saving its location and fetching
/// the trip every second through `LiveTripService`, while every request and delay is recorded.
///
/// Open it with `-DebugScreen loadCheck`. Debug builds only; its text is for developers and is not localized.
@Observable
final class LoadCheckViewModel {
    private(set) var isRunning = false
    private(set) var elapsed: Duration = .zero
    private(set) var summary: LoadCheckSummary?
    private(set) var errorMessage: String?
    private(set) var savedFile: URL?
    var carCount = 5
    var minutes = 30

    private let database: any CloudDatabase
    private let tick: Duration
    private let resultsFolder: URL

    /// - Parameters:
    ///   - database: the real public database on a phone, a fake in tests.
    ///   - tick: how often each car saves and fetches (1 second in the app, as in "Sync and timing").
    ///   - resultsFolder: where the Markdown report is saved.
    init(database: any CloudDatabase, tick: Duration = .seconds(1), resultsFolder: URL = .documentsDirectory) {
        self.database = database
        self.tick = tick
        self.resultsFolder = resultsFolder
    }

    /// Runs the check for `duration`, then ends the test trip and saves the report.
    func Run(for duration: Duration) async {
        guard isRunning == false else { return }
        isRunning = true
        errorMessage = nil
        savedFile = nil
        elapsed = .zero
        let recorder = LoadCheckRecorder()
        let database = MeasuringCloudDatabase(self.database, recorder: recorder)
        do {
            let (tripID, cars) = try await PrepareCars(database: database)
            await Drive(cars, tripID: tripID, recorder: recorder, for: duration)
            if let leader = cars.first {
                try? await leader.service.EndTrip(tripID: tripID, by: leader.participantID)
            }
        } catch {
            errorMessage = String(localized: TripServiceError(cloudKitError: error).message)
        }
        let summary = recorder.Summary(carCount: carCount, elapsed: elapsed)
        self.summary = summary
        savedFile = SaveReport(summary)
        isRunning = false
    }

    // MARK: Cars

    /// Creates a test trip with the first car as leader, adds the other cars as members, and starts the trip.
    /// Every car is its own `LiveTripService`, like a phone, but all of them use this phone's iCloud account.
    private func PrepareCars(
        database: MeasuringCloudDatabase
    ) async throws -> (UUID, [(service: LiveTripService, participantID: UUID)]) {
        let leader = LiveTripService(database: database, pollInterval: tick)
        let session = try await leader.CreateTrip(plan: SampleTrip.plan, profile: Profile(number: 1))
        let tripID = session.state.trip.id
        var cars = [(service: leader, participantID: session.myParticipantID)]
        for number in stride(from: 2, through: carCount, by: 1) {
            let member = Participant.Joining(
                tripID: tripID,
                userRecordID: "_loadcheck-car-\(number)",
                profile: Profile(number: number),
                at: .now
            )
            try await database.Save([TripRecordMapper.MakeRecord(member)], savePolicy: .allKeys)
            cars.append((service: LiveTripService(database: database, pollInterval: tick), participantID: member.id))
        }
        try await leader.StartTrip(tripID: tripID, by: session.myParticipantID)
        return (tripID, cars)
    }

    /// Every car saves its position and follows the trip every tick until `duration` has passed.
    private func Drive(
        _ cars: [(service: LiveTripService, participantID: UUID)],
        tripID: UUID,
        recorder: LoadCheckRecorder,
        for duration: Duration
    ) async {
        let start = ContinuousClock.now
        await withTaskGroup(of: Void.self) { group in
            for (index, car) in cars.enumerated() {
                group.addTask { await self.SendPositions(of: car, place: index, tripID: tripID) }
                group.addTask { await self.WatchOtherCars(from: car, tripID: tripID, recorder: recorder) }
            }
            group.addTask { await self.TrackProgress(since: start, recorder: recorder) }
            try? await Task.sleep(for: duration)
            group.cancelAll()
        }
        elapsed = start.duration(to: .now)
    }

    private func SendPositions(
        of car: (service: LiveTripService, participantID: UUID),
        place: Int,
        tripID: UUID
    ) async {
        var second = 0
        while Task.isCancelled == false {
            // About 40 km/h, with the cars 150 m apart.
            let update = LocationUpdate(
                coordinate: Position(metresAlongRoute: Double(second) * 11 + Double(carCount - place) * 150),
                speedKmh: 40,
                motionState: .driving,
                recordedAt: .now
            )
            try? await car.service.UpdateLocation(update, participantID: car.participantID, tripID: tripID)
            second += 1
            try? await Task.sleep(for: tick)
        }
    }

    /// Records, for every new position of another car, the time between that car saving it and this car seeing it.
    private func WatchOtherCars(
        from car: (service: LiveTripService, participantID: UUID),
        tripID: UUID,
        recorder: LoadCheckRecorder
    ) async {
        var lastSeen: [UUID: Date] = [:]
        for await state in car.service.TripUpdates(tripID: tripID) {
            let now = Date.now
            for other in state.participants where other.id != car.participantID && other.coordinate != nil {
                guard other.lastSeenAt > lastSeen[other.id, default: .distantPast] else { continue }
                recorder.RecordDelay(seconds: now.timeIntervalSince(other.lastSeenAt))
                lastSeen[other.id] = other.lastSeenAt
            }
        }
    }

    private func TrackProgress(since start: ContinuousClock.Instant, recorder: LoadCheckRecorder) async {
        while Task.isCancelled == false {
            elapsed = start.duration(to: .now)
            summary = recorder.Summary(carCount: carCount, elapsed: elapsed)
            try? await Task.sleep(for: tick)
        }
    }

    // MARK: Helpers

    private func Profile(number: Int) -> ParticipantProfile {
        ParticipantProfile(displayName: "Load car \(number)", carDescription: "Load check")
    }

    /// A point `metresAlongRoute` along the sample route, starting over at the start point after the destination.
    private func Position(metresAlongRoute distance: Double) -> Coordinate {
        let route = SampleTrip.plan.polyline
        let legs = Array(zip(route, route.dropFirst()))
        let length = legs.reduce(0) { $0 + $1.0.Distance(to: $1.1) }
        guard length > 0 else { return route.first ?? Coordinate(latitude: 0, longitude: 0) }
        var remaining = distance.truncatingRemainder(dividingBy: length)
        for (from, to) in legs {
            let legLength = from.Distance(to: to)
            if remaining <= legLength, legLength > 0 {
                let fraction = remaining / legLength
                return Coordinate(
                    latitude: from.latitude + (to.latitude - from.latitude) * fraction,
                    longitude: from.longitude + (to.longitude - from.longitude) * fraction
                )
            }
            remaining -= legLength
        }
        return route.last ?? Coordinate(latitude: 0, longitude: 0)
    }

    /// Saves the report as Markdown in the results folder, so it can be copied off the phone into the issue.
    private func SaveReport(_ summary: LoadCheckSummary) -> URL? {
        let stamp = Date.now.formatted(.iso8601).replacing(":", with: "")
        let file = resultsFolder.appending(path: "load-check-\(stamp).md")
        let report = "# CloudKit load check\n\nRun on one phone, ended \(Date.now.formatted(.iso8601)).\n\n"
            + summary.Markdown() + "\n"
        do {
            try report.write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            errorMessage = "Could not save the report: \(error.localizedDescription)"
            return nil
        }
    }
}
#endif
