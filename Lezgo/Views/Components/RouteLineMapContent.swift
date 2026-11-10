//
//  RouteLineMapContent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 10/11/26.
//

import MapKit
import SwiftUI

/// The group's route as every map draws it, from planning to the trip itself: a yellow line on a dark casing, so it
/// stands out on the muted map (`MapStyle.lezgo`).
struct RouteLineMapContent: MapContent {
    let coordinates: [CLLocationCoordinate2D]

    var body: some MapContent {
        MapPolyline(coordinates: coordinates)
            .stroke(Color(.tripCard), style: Self.Stroke(width: 16))
        MapPolyline(coordinates: coordinates)
            .stroke(Color(.brandYellow), style: Self.Stroke(width: 8))
    }

    /// A round-ended line, so the route's corners and ends look smooth.
    static func Stroke(width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}
