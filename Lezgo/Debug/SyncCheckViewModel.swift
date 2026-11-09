//
//  SyncCheckViewModel.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

#if DEBUG
import Foundation
import Observation

/// A developer tool that drives the real `TripService` on a phone, to check iCloud sync between phones (#111).
///
/// Open it with `-DebugScreen syncCheck`. Debug builds only; its text is for developers and is not localized.
@Observable
final class SyncCheckViewModel {
    private(set) var session: TripSession?
    private(set) var state: TripState?
    private(set) var log: [LogEntry] = []
    private(set) var errorMessage: String?
    private(set) var isBusy = false
    var roomCodeInput = ""

    private let tripService: any TripService
    private let clock: () -> Date

    init(tripService: any TripService, clock: @escaping () -> Date = { .now }) {
        self.tripService = tripService
        self.clock = clock
    }

    var myParticipantID: UUID? {
        session?.myParticipantID
    }

    var isLeader: Bool {
        guard let state, let myParticipantID else { return false }
        return state.trip.leaderParticipantID == myParticipantID
    }

    /// The live trip map (#170) can open once the trip is on the road.
    var canOpenMap: Bool {
        state?.trip.status == .inTrip && myParticipantID != nil
    }

    var canJoin: Bool {
        Trip.IsValidRoomCode(roomCodeInput)
    }

    func CreateTrip() async {
        await Perform("Created the trip") {
            let session = try await tripService.CreateTrip(plan: SampleTrip.plan, profile: nil)
            Begin(session)
        }
    }

    func JoinTrip() async {
        guard canJoin else { return }
        await Perform("Joined trip \(roomCodeInput)") {
            let session = try await tripService.JoinTrip(roomCode: roomCodeInput, profile: nil)
            Begin(session)
        }
    }

    func StartTrip() async {
        await PerformOnTrip("Started the trip") { tripID, myID in
            try await tripService.StartTrip(tripID: tripID, by: myID)
        }
    }

    func HandOverLead(to participantID: UUID) async {
        await PerformOnTrip("Handed over the lead") { tripID, myID in
            try await tripService.SetLeader(participantID, tripID: tripID, replacing: myID)
        }
    }

    func EndTrip() async {
        await PerformOnTrip("Ended the trip") { tripID, myID in
            try await tripService.EndTrip(tripID: tripID, by: myID)
        }
    }

    /// Follows the trip until the task is cancelled.
    func Listen() async {
        guard let tripID = session?.state.trip.id else { return }
        for await newState in tripService.TripUpdates(tripID: tripID) {
            Apply(newState)
        }
    }

    /// Shows a new state and logs what changed since the last one.
    func Apply(_ newState: TripState) {
        if let state {
            Changes(from: state, to: newState).forEach(Log)
        }
        state = newState
    }

    // MARK: Helpers

    private func Begin(_ newSession: TripSession) {
        session = newSession
        state = newSession.state
    }

    /// Runs one action, shows its error if it fails, and logs it if it works.
    private func Perform(_ success: String, _ action: () async throws -> Void) async {
        guard isBusy == false else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await action()
            errorMessage = nil
            Log(success)
        } catch let error as TripServiceError {
            errorMessage = String(localized: error.message)
        } catch {
            errorMessage = String(localized: TripServiceError(cloudKitError: error).message)
        }
    }

    /// An action on the current trip, followed by a fresh fetch so the screen shows the result at once.
    private func PerformOnTrip(_ success: String, _ action: (UUID, UUID) async throws -> Void) async {
        guard let tripID = session?.state.trip.id, let myID = myParticipantID else { return }
        await Perform(success) {
            try await action(tripID, myID)
            Apply(try await tripService.FetchTrip(tripID: tripID))
        }
    }

    private func Log(_ message: String) {
        log.insert(LogEntry(seenAt: clock(), message: message), at: 0)
    }

    private func Changes(from old: TripState, to new: TripState) -> [String] {
        let oldIDs = Set(old.participants.map(\.id))
        let newIDs = Set(new.participants.map(\.id))
        var changes = new.participants.filter { oldIDs.contains($0.id) == false }.map { "\($0.displayName) joined" }
        changes += old.participants.filter { newIDs.contains($0.id) == false }.map { "\($0.displayName) left" }
        if old.trip.leaderParticipantID != new.trip.leaderParticipantID {
            let name = new.leader?.displayName ?? "Someone"
            changes.append("\(name) is now the leader")
        }
        if old.trip.status != new.trip.status {
            changes.append("Trip is \(new.trip.status.rawValue)")
        }
        if old.trip.routeVersion != new.trip.routeVersion {
            changes.append("Route version \(new.trip.routeVersion)")
        }
        return changes
    }
}

extension SyncCheckViewModel {
    /// One line in the Sync Check log: what changed in the trip, and when this phone saw it.
    struct LogEntry: Identifiable, Hashable {
        let id = UUID()
        let seenAt: Date
        let message: String
    }
}
#endif
