//
//  TripMapViewModel+Live.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 30/10/26.
//

import Foundation

extension TripMapViewModel {
    /// The trip map on a real phone: MapKit guidance and street names, this phone's GPS shared every second, and the
    /// leader's automatic reroute. Every screen that opens the map uses this, so they all behave the same.
    convenience init(
        session: TripSession,
        tripService: any TripService,
        activeTripStorage: any ActiveTripStorage
    ) {
        let tripID = session.state.trip.id
        self.init(
            tripID: tripID,
            myParticipantID: session.myParticipantID,
            tripService: tripService,
            navigator: LiveTripMapNavigator(),
            streetNameService: LiveStreetNameService(),
            locationSharer: LocationSharer(
                tripService: tripService,
                locationProvider: LiveLocationProvider(),
                tripID: tripID,
                participantID: session.myParticipantID
            ),
            directionsService: LiveDirectionsService(),
            activeTripStorage: activeTripStorage
        )
    }
}
