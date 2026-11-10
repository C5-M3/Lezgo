//
//  MapStyle+Lezgo.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 10/11/26.
//

import MapKit
import SwiftUI

extension MapStyle {
    /// The one look of every map in the app, from planning to the trip itself: Apple's standard map, muted so the
    /// yellow route, the pins and the robots stand out, with no points of interest to read while driving.
    static let lezgo = MapStyle.standard(emphasis: .muted, pointsOfInterest: .excludingAll)
}
