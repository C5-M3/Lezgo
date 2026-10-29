//
//  TripMapViewModel+EditRoute.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 29/10/26.
//

import Foundation

// Edit Route lives in its own file so `TripMapViewModel.swift` stays under SwiftLint's 400-line limit.

extension TripMapViewModel {
    /// "Edit Route" on the leader's map: the planner from the leader's position through what is left of the route.
    func RequestEditRoute() {
        guard editRoute == nil, closeReason == nil, isLeader, let state, let myCoordinate,
              let waypoints = state.RemainingWaypoints(from: .CurrentLocation(at: myCoordinate)) else { return }
        editRoute = EditRouteViewModel(
            startingWaypoints: waypoints,
            tripID: tripID,
            myParticipantID: myParticipantID,
            tripService: tripService
        )
    }

    /// "Cancel" in Edit Route, or the route was saved.
    func CloseEditRoute() {
        editRoute = nil
    }

    /// A leader who handed over the lead, or whose trip closed, can no longer change the route.
    func CloseEditRouteIfNotAllowed() {
        guard closeReason != nil || isLeader == false else { return }
        editRoute = nil
    }
}
