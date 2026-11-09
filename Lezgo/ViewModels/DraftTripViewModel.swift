//
//  DraftTripViewModel.swift
//  Lezgo
//
//  Created by Rizal Pratama on 27/10/26.
//

import Foundation
import Observation

/// Drives the prompt shown when the app opens with an active trip saved on the phone (US-03).
///
/// Keeps the saved trip summary, presents the confirmation for "New Trip" and runs the
/// user's choice:
/// - Continue: Handled by the parent `HomeViewModel` to restore the trip room or map.
/// - New Trip: Prompts first, leaves the old trip (End for leader, Exit for member), clears
///   storage, and opens the trip planner.
@Observable
@MainActor
final class DraftTripViewModel {
    // MARK: - Properties

    var summary: ActiveTripSummary
    private let tripService: any TripService
    private let storage: any ActiveTripStorage

    var isConfirmingNewTrip: Bool = false
    var isPerformingAction: Bool = false
    var errorMessage: String?
    var wasCancelledByLeader: Bool = false

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

    var memberCount: Int {
        summary.memberNames.count
    }

    var statusText: String {
        switch summary.status {
        case .lobby: return "Lobby"
        case .inTrip: return "In Trip"
        case .ended: return "Ended"
        case .cancelled: return "Cancelled"
        }
    }

    var tripInfoText: String {
        let count = max(memberCount, 1)
        let countDescription = count == 1 ? "1 person" : "\(count) people"
        return "\(countDescription) · \(statusText)"
    }

    var isLeader: Bool {
        summary.isLeader
    }

    var startCoordinate: Coordinate? {
        summary.startCoordinate
    }

    var destinationCoordinate: Coordinate? {
        summary.destinationCoordinate
    }

    var routeCoordinates: [Coordinate] {
        summary.routeCoordinates ?? []
    }

    var estimatedDuration: TimeInterval? {
        summary.estimatedDuration
    }

    var durationText: String? {
        guard let duration = summary.estimatedDuration, duration > 0 else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }

    var confirmTitle: String {
        "Create a new trip?"
    }

    var confirmMessage: String? {
        isLeader ? "Your current trip will end for everyone" : nil
    }

    var cancelledTitle: String {
        String(localized: "Trip Cancelled")
    }

    var cancelledMessage: String {
        String(localized: "Your last trip was cancelled by leader")
    }

    // MARK: - User Actions

    func TapNewTrip() {
        isConfirmingNewTrip = true
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
                if !isLeader {
                    wasCancelledByLeader = true
                }
                return false
            }
            Apply(state)
            return true
        } catch let error as TripServiceError where error == .notFound || error == .tripEnded {
            storage.ClearActiveTrip()
            if !isLeader {
                wasCancelledByLeader = true
            }
            return false
        } catch {
            return true
        }
    }

    /// Keeps the saved-trip card current while it is visible, including when another participant leaves.
    func Listen() async {
        for await state in tripService.TripUpdates(tripID: summary.tripID) {
            if state.trip.status == .ended || state.trip.status == .cancelled {
                storage.ClearActiveTrip()
                if !isLeader {
                    isConfirmingNewTrip = false
                    wasCancelledByLeader = true
                }
                summary.status = state.trip.status
                return
            }
            Apply(state)
        }
    }

    private func Apply(_ state: TripState) {
        var refreshedSummary = summary
        refreshedSummary.status = state.trip.status
        refreshedSummary.isLeader = state.trip.leaderParticipantID == summary.myParticipantID
        refreshedSummary.memberNames = state.participants.map(state.DisplayName)

        if let start = state.waypoints.first(where: { $0.kind == .start })?.coordinate {
            refreshedSummary.startCoordinate = start
        }
        if let destination = state.destination?.coordinate {
            refreshedSummary.destinationCoordinate = destination
        }
        if let polyline = state.route?.polyline, !polyline.isEmpty {
            refreshedSummary.routeCoordinates = polyline
        }

        guard refreshedSummary != summary else { return }
        summary = refreshedSummary
        storage.SaveActiveTrip(refreshedSummary)
    }
}

#if DEBUG
extension DraftTripViewModel {
    private static let sampleRouteCoordinates: [Coordinate] = [
        Coordinate(latitude: -7.2858, longitude: 112.6318),
        Coordinate(latitude: -7.2855, longitude: 112.6520),
        Coordinate(latitude: -7.2872, longitude: 112.6780),
        Coordinate(latitude: -7.2905, longitude: 112.7020),
        Coordinate(latitude: -7.2923, longitude: 112.7190)
    ]

    static var sample: DraftTripViewModel {
        let sampleSummary = ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            roomCode: "897654",
            startName: "Universitas Ciputra",
            destinationName: "Ciputra World Surabaya",
            distanceText: "9 km",
            memberNames: ["Agus", "Budi", "Citra", "Doni"],
            status: .lobby,
            isLeader: false,
            startCoordinate: Coordinate(latitude: -7.2858, longitude: 112.6318),
            destinationCoordinate: Coordinate(latitude: -7.2923, longitude: 112.7190),
            routeCoordinates: sampleRouteCoordinates
        )
        return DraftTripViewModel(
            summary: sampleSummary,
            tripService: SampleTrip.Service()
        )
    }

    static var sampleLeader: DraftTripViewModel {
        let sampleSummary = ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            roomCode: "897654",
            startName: "Universitas Ciputra",
            destinationName: "Ciputra World Surabaya",
            distanceText: "9 km",
            memberNames: ["Agus", "Budi", "Citra", "Doni"],
            status: .lobby,
            isLeader: true,
            startCoordinate: Coordinate(latitude: -7.2858, longitude: 112.6318),
            destinationCoordinate: Coordinate(latitude: -7.2923, longitude: 112.7190),
            routeCoordinates: sampleRouteCoordinates
        )
        return DraftTripViewModel(
            summary: sampleSummary,
            tripService: SampleTrip.Service()
        )
    }
}
#endif
