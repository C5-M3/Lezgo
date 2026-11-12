//
//  TripMapViewModel+Activity.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

extension TripMapViewModel {
    /// What the trip's Live Activity shows now (ADR 0027), or `nil` before the trip has loaded and after it closed.
    var activitySnapshot: TripActivityUpdater.Snapshot? {
        guard closeReason == nil, state != nil, let destinationName else { return nil }
        let input = TripActivityContent.Input(
            guidance: guidance,
            isRerouting: isRerouting,
            cars: carPins,
            route: route,
            upcomingWaypoints: upcomingWaypoints,
            alertBanner: alertBanner,
            arrivalCard: arrivalCard,
            arrivalProgress: arrivalProgress,
            isMuted: sound.isMuted,
            now: updatedAt ?? .now
        )
        return TripActivityUpdater.Snapshot(
            tripMapID: ObjectIdentifier(self),
            attributes: TripActivityContent.Attributes(destinationName: destinationName),
            state: TripActivityContent.State(input)
        )
    }
}
