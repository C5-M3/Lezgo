//
//  EditRouteViewModel.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 29/10/26.
//

import Foundation
import Observation

/// State and logic for the planner the leader opens from the map: Edit Route on the road (`specs/UserStories.md` →
/// US-06, "Route changes") and New Destination after arriving (US-07, "New Destination").
///
/// Edit Route starts from the leader's position, the unvisited checkpoints and the destination; saving makes the
/// changed route the trip's next route version, so every phone switches to it. New Destination starts at the old
/// destination; saving sets the trip back to `LOBBY` with the new route, so every phone opens the Trip Room.
@Observable
final class EditRouteViewModel: Identifiable {
    /// What the planner shows when it opens.
    let startingWaypoints: [PlannedWaypoint]
    let purpose: Purpose
    /// `true` while the route is on its way; Save is disabled meanwhile.
    private(set) var isSaving = false
    /// Set once the route is saved; the sheet then closes.
    private(set) var didSave = false
    /// Why saving failed, for example no network; the sheet stays open so the leader can try again.
    private(set) var errorMessage: String?

    private let tripID: UUID
    private let myParticipantID: UUID
    private let tripService: any TripService

    init(
        startingWaypoints: [PlannedWaypoint],
        tripID: UUID,
        myParticipantID: UUID,
        tripService: any TripService,
        purpose: Purpose = .editRoute
    ) {
        self.startingWaypoints = startingWaypoints
        self.purpose = purpose
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.tripService = tripService
    }

    /// Saves the route for everyone. Repeated taps while saving, or after the route was saved, do nothing.
    func Save(_ plan: TripPlan) async {
        guard isSaving == false, didSave == false else { return }
        guard plan.isValid else {
            errorMessage = String(localized: TripServiceError.notAllowed.message)
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            switch purpose {
            case .editRoute: try await tripService.SaveRoute(plan, tripID: tripID, by: myParticipantID)
            case .newDestination: try await tripService.StartNewDestination(plan, tripID: tripID, by: myParticipantID)
            }
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

extension EditRouteViewModel {
    /// What saving the planner does.
    enum Purpose: Hashable {
        /// Edit Route: the changed route replaces the current one on the road.
        case editRoute
        /// New Destination: the next leg of the trip, planned from the Trip Room again.
        case newDestination
    }
}
