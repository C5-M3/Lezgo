//
//  LocationSharer+Live.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation

extension LocationSharer {
    /// The sharer on a real phone: this phone's GPS, sent once a second. The Trip Room and the trip map both use it,
    /// so the group sees who is at the start point and where every car is on the road.
    /// - Parameter keepsRunningInBackground: `true` only on the trip map, so sharing goes on with the screen locked
    ///   while driving, and never after the trip (see `LiveLocationProvider`).
    convenience init(
        tripService: any TripService,
        tripID: UUID,
        participantID: UUID,
        keepsRunningInBackground: Bool = false
    ) {
        self.init(
            tripService: tripService,
            locationProvider: LiveLocationProvider(keepsRunningInBackground: keepsRunningInBackground),
            tripID: tripID,
            participantID: participantID
        )
    }
}
