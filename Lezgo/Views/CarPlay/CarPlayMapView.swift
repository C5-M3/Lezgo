//
//  CarPlayMapView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import MapKit
import SwiftUI

/// The CarPlay base view: only the map, as Apple requires of navigation apps (ADR 0023). With a trip open on the
/// phone it is the same map as the phone's, with the yellow route, the stops and the robot cars; otherwise it shows
/// where the car is. Every button, card and alert is a CarPlay template drawn by the system on top.
struct CarPlayMapView: View {
    let activeTripMap: ActiveTripMap

    var body: some View {
        if let tripMap = activeTripMap.tripMap, tripMap.closeReason == nil {
            TripMapView.MapLayer(viewModel: tripMap)
                // A new trip map starts with a fresh camera instead of the last trip's.
                .id(ObjectIdentifier(tripMap))
        } else {
            Map(initialPosition: .userLocation(fallback: .automatic)) {
                UserAnnotation()
            }
            .mapStyle(.lezgo)
            .mapControls {}
        }
    }
}

#Preview("No trip") {
    CarPlayMapView(activeTripMap: ActiveTripMap())
        .frame(width: 800, height: 480)
}

#Preview("No trip, dark") {
    CarPlayMapView(activeTripMap: ActiveTripMap())
        .frame(width: 800, height: 480)
        .preferredColorScheme(.dark)
}
