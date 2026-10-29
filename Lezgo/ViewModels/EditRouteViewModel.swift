//
//  EditRouteViewModel.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 29/10/26.
//

import Foundation
import Observation

/// State and logic for Edit Route, the planner the leader opens on the road (`specs/UserStories.md` → US-06,
/// "Route changes").
///
/// The planner starts from `startingWaypoints`: the leader's position, the unvisited checkpoints and the destination.
/// Saving makes the changed route the trip's next route version, so every phone switches to it.
@Observable
final class EditRouteViewModel {
    /// What the planner shows when it opens.
    let startingWaypoints: [PlannedWaypoint]
    /// `true` while the route is on its way; Save is disabled meanwhile.
    private(set) var isSaving = false
    /// Set once the route is saved; the sheet then closes.
    private(set) var didSave = false
    /// Why saving failed, for example no network; the sheet stays open so the leader can try again.
    private(set) var errorMessage: String?

    private let tripID: UUID
    private let myParticipantID: UUID
    private let tripService: any TripService

    init(startingWaypoints: [PlannedWaypoint], tripID: UUID, myParticipantID: UUID, tripService: any TripService) {
        self.startingWaypoints = startingWaypoints
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.tripService = tripService
    }

    /// Saves the changed route for everyone. Repeated taps while saving, or after the route was saved, do nothing.
    func Save(_ plan: TripPlan) async {
        guard isSaving == false, didSave == false else { return }
        guard plan.isValid else {
            errorMessage = String(localized: TripServiceError.notAllowed.message)
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await tripService.SaveRoute(plan, tripID: tripID, by: myParticipantID)
            didSave = true
            errorMessage = nil
        } catch {
            errorMessage = String(localized: TripServiceError(cloudKitError: error).message)
        }
    }

    /// "OK" on the message that saving failed.
    func DismissError() {
        errorMessage = nil
    }
}
