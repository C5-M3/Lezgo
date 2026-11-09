//
//  LocationUpdate.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// One location reading from this phone, sent about once per second while a trip is open.
struct LocationUpdate: Hashable {
    var coordinate: Coordinate
    var speedKmh: Double
    var motionState: MotionState
    var recordedAt: Date
    /// The way the car is heading, in degrees clockwise from north; `nil` when the phone does not know.
    var course: Double?
}
