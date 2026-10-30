//
//  TripMapCarPin.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// A car pin as the trip map draws it: the car plus the facts the pin's look depends on.
struct TripMapCarPin: Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var coordinate: Coordinate
    var motionState: MotionState
    /// The way the car is heading, in degrees clockwise from north; `nil` draws the car without a direction.
    var course: Double?
    var isLeader: Bool
    var isMe: Bool
    /// Offline cars stay at their last position and are drawn faded.
    var isOffline: Bool
    /// Another car that is off the route or ahead of the leader; its pin is highlighted.
    var isAlerting = false
}
