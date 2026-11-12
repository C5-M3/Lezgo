//
//  TripMapViewModel+Activity.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

extension TripMapViewModel {
    /// What the trip's Live Activity shows now (ADR 0028), or `nil` before the trip has loaded and after it closed.
    var activitySnapshot: TripActivityUpdater.Snapshot? {
        guard closeReason == nil, let state, let destinationName else { return nil }
        let input = TripActivityContent.Input(
            guidance: guidance,
            cars: carPins,
            route: route,
            waypoints: waypoints,
            currentWaypointIndex: state.trip.currentWaypointIndex,
            arrivalCard: arrivalCard,
            arrivalProgress: arrivalProgress
        )
        return TripActivityUpdater.Snapshot(
            tripMapID: ObjectIdentifier(self),
            attributes: TripActivityContent.Attributes(destinationName: destinationName),
            state: TripActivityContent.State(input)
        )
    }
}
