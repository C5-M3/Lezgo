//
//  TripMapGuidance.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// Turn-by-turn guidance for this phone's car: the next turn and the time left to the destination.
struct TripMapGuidance: Hashable {
    var direction: TurnDirection
    /// The instruction from the routing service, for example "Turn right". MapKit already localizes it.
    var instruction: String
    var distanceToTurn: Measurement<UnitLength>
    var timeLeft: Duration
}

extension TripMapGuidance {
    /// Which way the next turn goes, so the turn card can show the matching arrow.
    enum TurnDirection: Hashable {
        case left
        case right
        case straight
    }
}
