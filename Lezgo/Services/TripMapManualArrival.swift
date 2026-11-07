//
//  TripMapManualArrival.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Observation

/// "I've Arrived" (`specs/UserStories.md` → US-07, "Arrive").
///
/// A destination's point is not always where the group stops: in a big mall the car can be parked 200 m from it and
/// never come within the 20 m that counts as arrived. Within 1 km of the point the driver can say they arrived. The
/// question first tells them how far the point is, so a tap while still driving there is easy to undo. The button
/// shows only near the destination, so it is never one stray tap away on the road.
@Observable
final class TripMapManualArrival {
    /// The question before saving: how far this car is from the destination's point.
    struct Confirmation: Hashable {
        let destinationID: UUID
        let destinationName: String
        let distance: Measurement<UnitLength>
    }

    /// How close to the destination's point the button shows, in metres.
    static let maxDistance = 1_000.0
    /// The distance in the question is rounded to this, in metres: GPS is not more precise than that.
    private static let roundedTo = 10.0

    /// The question while it is open, or `nil`.
    private(set) var confirmation: Confirmation?
    /// Why saving failed, for example no network; the button stays so the driver can try again.
    private(set) var errorMessage: String?
    /// `true` while the arrival is on its way; the question's button is disabled meanwhile.
    private(set) var isSaving = false

    private let tripID: UUID
    private let myParticipantID: UUID
    private let tripService: any TripService

    init(tripID: UUID, myParticipantID: UUID, tripService: any TripService) {
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.tripService = tripService
    }

    /// `true` on the road within 1 km of the destination, until this car has arrived (by its position or by hand).
    func CanMark(in state: TripState?, from myCoordinate: Coordinate?) -> Bool {
        Distance(in: state, from: myCoordinate) != nil
    }

    /// Opens the question, with the distance to the destination's point.
    func Request(in state: TripState?, from myCoordinate: Coordinate?) {
        guard isSaving == false, let state, let destination = state.destination,
              let metres = Distance(in: state, from: myCoordinate) else { return }
        let rounded = (metres / Self.roundedTo).rounded() * Self.roundedTo
        confirmation = Confirmation(
            destinationID: destination.id,
            destinationName: destination.name,
            distance: Measurement(value: rounded, unit: .meters)
        )
    }

    /// "Cancel": nothing is saved.
    func Cancel() {
        confirmation = nil
    }

    /// "I've Arrived" in the question: saves it, and every phone counts this car as arrived with its next update.
    ///
    /// The view passes the confirmation it showed, because the dialog closes before the task that calls this runs.
    func Confirm(_ confirmation: Confirmation) async {
        guard isSaving == false else { return }
        isSaving = true
        defer { isSaving = false }
        self.confirmation = nil
        do {
            try await tripService.MarkArrived(
                at: confirmation.destinationID,
                participantID: myParticipantID,
                tripID: tripID
            )
            errorMessage = nil
        } catch {
            errorMessage = String(localized: TripServiceError(cloudKitError: error).message)
        }
    }

    /// "OK" on the message that saving failed.
    func DismissError() {
        errorMessage = nil
    }

    /// The distance from this car to the destination's point, or `nil` when the button should not show.
    private func Distance(in state: TripState?, from myCoordinate: Coordinate?) -> Double? {
        guard let state, state.trip.status == .inTrip, let destination = state.destination,
              let myCoordinate else { return nil }
        // Arrival ignores the time for this phone's own car, so any date does.
        guard TripMapArrival.Check(state, myParticipantID: myParticipantID, at: .now).hasArrived == false else {
            return nil
        }
        let metres = myCoordinate.Distance(to: destination.coordinate)
        return metres <= Self.maxDistance ? metres : nil
    }
}
