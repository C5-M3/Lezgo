//
//  DrivingDirections.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 30/10/26.
//

import Foundation

/// MapKit's driving directions as plain values, so `LiveTripMapNavigator` can be tested without MapKit.
struct DrivingDirections: Hashable {
    /// In driving order. Each step starts with the turn its instruction describes.
    var steps: [Step]
    /// Seconds from the first step to the end of the last, as MapKit expects them with traffic.
    var expectedTravelTime: TimeInterval
}

extension DrivingDirections {
    /// One manoeuvre and the road up to the next one, like `MKRoute.Step`.
    struct Step: Hashable {
        /// MapKit's own text, already localized, for example "Turn right onto Jalan Darmo". The first step's is often
        /// empty.
        var instruction: String
        /// The road of this step, starting where the turn happens.
        var path: [Coordinate]
    }
}
