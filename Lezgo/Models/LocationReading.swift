//
//  LocationReading.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation

/// One GPS reading from this phone.
struct LocationReading: Hashable {
    var coordinate: Coordinate
    /// Speed in km/h, never negative: CoreLocation's "unknown" speed is read as 0.
    var speedKmh: Double
    var recordedAt: Date
    /// The way the car is heading, in degrees clockwise from north; `nil` when the phone does not know.
    var course: Double?
    /// `false` for a fix too rough to place the car on its street, as every fix is with Precise Location off. Such a
    /// reading is never shared; the screens ask the person to turn Precise Location on instead.
    var isPrecise = true
}
