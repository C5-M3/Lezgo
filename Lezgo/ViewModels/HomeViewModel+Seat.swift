//
//  HomeViewModel+Seat.swift
//  Lezgo
//
//  Created by Oky Faishal on 16/11/26.
//

import Foundation

extension HomeViewModel {
    /// Asks iCloud which trip this account is in and shows Home or Draft Trip for it, whatever this phone saved
    /// (ADR 0031). The phone's own copy only gives a fast first screen. When iCloud cannot be reached the copy stays,
    /// unless it belongs to another iCloud account.
    func RefreshActiveTrip(tripService: any TripService) async {
        guard let account = try? await tripService.AccountID() else { return }
        if let owner = activeDraftTrip?.accountID, owner != account {
            ClearActiveDraftTrip()
        }
        let before = activeDraftTrip
        let found: TripSession?
        do {
            found = try await tripService.MyTrip()
        } catch {
            // Only a clear "no trip" empties Draft Trip: when the question failed, nothing is known.
            return
        }
        // The person may have created or opened a trip while iCloud was answering; that is newer than the answer.
        guard activeDraftTrip == before, activeTripSession == nil, activeMapSession == nil else { return }
        guard let session = found else {
            ClearActiveDraftTrip()
            isDraftTripFromAnotherPhone = false
            return
        }
        ShowDraftTrip(of: session, account: account, savedHere: before)
    }

    /// "Continue" on Draft Trip: asks first when the trip is in another phone's hands, and goes on at once otherwise.
    func RequestContinue() {
        isConfirmingContinue = isDraftTripFromAnotherPhone
    }

    private func ShowDraftTrip(of session: TripSession, account: String, savedHere: ActiveTripSummary?) {
        var summary = ActiveTripSummary.From(session: session)
        let isSameTrip = savedHere?.tripID == session.state.trip.id
        if isSameTrip {
            // The distance and the time came from the planner on this phone; the trip itself does not have them.
            summary.distanceText = savedHere?.distanceText
            summary.estimatedDuration = savedHere?.estimatedDuration
        }
        summary.accountID = account
        isDraftTripFromAnotherPhone = isSameTrip == false
        activeTripStorage.SaveActiveTrip(summary)
        activeDraftTrip = summary
    }
}
