//
//  DraftTripViewModel.swift
//  Lezgo
//
//  Created by Rizal Pratama on 27/10/26.
//

import Foundation
import Observation

/// ViewModel for managing the Draft Trip screen (US-03).
///
/// Shows the unfinished trip card ("You have a trip in progress") with start point,
/// destination, distance, and participants, allowing the user to continue or start a new trip.
@Observable
@MainActor
final class DraftTripViewModel {
    // MARK: - State Properties

    var summary: ActiveTripSummary
    var isConfirmingNewTrip: Bool = false
    var isPerformingAction: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let tripService: any TripService
    private let storage: any ActiveTripStorage

    // MARK: - Initializer

    init(
        summary: ActiveTripSummary,
        tripService: any TripService,
        storage: (any ActiveTripStorage)? = nil
    ) {
        self.summary = summary
        self.tripService = tripService
        self.storage = storage ?? UserDefaultsActiveTripStorage()
    }

    // MARK: - Computed Properties

    var startPointName: String {
        summary.startName
    }

    var destinationName: String {
        summary.destinationName
    }

    var distanceText: String {
        summary.distanceText ?? ""
    }

    var membersText: String {
        summary.memberNames.joined(separator: ", ")
    }

    var isLeader: Bool {
        summary.isLeader
    }

    var confirmTitle: String {
        "Create a new trip?"
    }

    var confirmMessage: String? {
        isLeader ? "Your current trip will end for everyone." : nil
    }

    // MARK: - User Actions

    func TapNewTrip() {
        isConfirmingNewTrip = true
    }

    func DismissConfirmation() {
        isConfirmingNewTrip = false
    }

    /// Handles confirming creation of a new trip:
    /// - For members: exits the current trip (ExitTrip).
    /// - For leaders: ends the trip for everyone (EndTrip).
    /// Clears the saved active trip from storage.
    @discardableResult
    func ConfirmNewTrip() async -> Bool {
        isPerformingAction = true
        defer {
            isPerformingAction = false
            isConfirmingNewTrip = false
        }

        do {
            if isLeader {
                try await tripService.EndTrip(tripID: summary.tripID, by: summary.myParticipantID)
            } else {
                try await tripService.ExitTrip(tripID: summary.tripID, participantID: summary.myParticipantID)
            }
            storage.ClearActiveTrip()
            return true
        } catch let error as TripServiceError {
            storage.ClearActiveTrip()
            errorMessage = String(localized: error.message)
            return true
        } catch {
            storage.ClearActiveTrip()
            return true
        }
    }

    /// Checks the server status of the saved trip in the background.
    /// If the trip has ended or was cancelled, clears the local storage and returns false.
    @discardableResult
    func CheckServerStatus() async -> Bool {
        do {
            let state = try await tripService.FetchTrip(tripID: summary.tripID)
            if state.trip.status == .ended || state.trip.status == .cancelled {
                storage.ClearActiveTrip()
                return false
            }
            summary.status = state.trip.status
            summary.memberNames = state.participants.map(\.displayName)
            storage.SaveActiveTrip(summary)
            return true
        } catch {
            return true
        }
    }
}

#if DEBUG
extension DraftTripViewModel {
    static var sample: DraftTripViewModel {
        let sampleSummary = ActiveTripSummary(
            tripID: UUID(),
            myParticipantID: UUID(),
            roomCode: "897654",
            startName: "Universitas Ciputra",
            destinationName: "Ciputra World",
            distanceText: "9 km",
            memberNames: ["Nathan", "Mathew"],
            status: .lobby,
            isLeader: false
        )
        return DraftTripViewModel(
            summary: sampleSummary,
            tripService: SampleTrip.Service()
        )
    }

    static var sampleLeader: DraftTripViewModel {
        let sampleSummary = ActiveTripSummary(
            tripID: UUID(),
            myParticipantID: UUID(),
            roomCode: "897654",
            startName: "Universitas Ciputra",
            destinationName: "Ciputra World",
            distanceText: "9 km",
            memberNames: ["Nathan", "Mathew"],
            status: .lobby,
            isLeader: true
        )
        return DraftTripViewModel(
            summary: sampleSummary,
            tripService: SampleTrip.Service()
        )
    }
}
#endif
