//
//  TripMapHeading.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 10/11/26.
//

import Observation

/// Which way the phone's trip map is turned, shared by the map and its compass button. Its own object, so only the
/// compass redraws while the map turns, not the whole trip screen.
@Observable final class TripMapHeading {
    /// Degrees clockwise from north.
    private(set) var degrees = 0.0
    /// Goes up by one on each tap of the compass; the map turns back to north when it changes.
    private(set) var northRequest = 0

    /// How far the map may be turned before the compass shows, in degrees, so it does not flicker in and out.
    private static let northWithin = 2.0

    /// `true` while the map is turned away from north, when the compass shows.
    var isTurned: Bool {
        let turn = abs(degrees.truncatingRemainder(dividingBy: 360))
        return min(turn, 360 - turn) > Self.northWithin
    }

    /// The map moved; called on every frame of a turn, so an unchanged heading changes nothing.
    func Update(_ degrees: Double) {
        guard degrees != self.degrees else { return }
        self.degrees = degrees
    }

    /// The compass was tapped.
    func PointNorth() {
        northRequest += 1
    }
}
