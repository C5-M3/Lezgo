//
//  TripRoomViewModel+EditRoute.swift
//  Lezgo
//
//  Created by Oky Faishal on 09/11/26.
//

import Foundation

extension TripRoomViewModel {
    /// "Edit" is for the leader while the trip is still in the Trip Room.
    var canEditRoute: Bool {
        isCurrentUserLeader && tripStatus == .lobby && startPoint != nil && destination != nil
    }

    /// "Edit": the planner from the trip's start point through the checkpoints to the destination. Unlike Edit Route
    /// on the map it does not start from the leader's position, and the trip stays in the lobby.
    func RequestEditRoute() {
        guard editRoute == nil, canEditRoute, let state, let startPoint,
              let waypoints = state.RemainingWaypoints(
                from: PlannedWaypoint(kind: .start, name: startPoint.name, coordinate: startPoint.coordinate)
              ) else { return }
        editRoute = EditRouteViewModel(
            startingWaypoints: waypoints,
            tripID: tripID,
            myParticipantID: myParticipantID,
            tripService: tripService
        )
    }

    /// "Back" in the planner, or the route was saved.
    func CloseEditRoute() {
        editRoute = nil
    }

    /// A leader who handed over the lead, or whose trip started, can no longer change the route here.
    func CloseEditRouteIfNotAllowed() {
        guard canEditRoute == false else { return }
        editRoute = nil
    }
}
