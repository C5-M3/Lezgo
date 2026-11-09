//
//  TripMapWaypointPinView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// A checkpoint or destination still ahead on the trip map; passed stops are not shown.
struct TripMapWaypointPinView: View {
    let waypoint: Waypoint

    var body: some View {
        // The same pins as on the planner's map, so a stop looks the same before and during the trip.
        RouteStopPin(kind: waypoint.kind)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: waypoint.name))
            .accessibilityValue(Text(Kind()))
    }

    private func Kind() -> LocalizedStringResource {
        switch waypoint.kind {
        case .start: .tripMapStartPoint
        case .checkpoint: .tripMapCheckpoint
        case .destination: .tripMapDestination
        }
    }
}

#Preview("Every kind of waypoint") {
    let coordinate = Coordinate(latitude: 0, longitude: 0)
    let stops: [(WaypointKind, String)] = [
        (.start, "Tunjungan Plaza"),
        (.checkpoint, "Ciputra World"),
        (.destination, "Pakuwon mall")
    ]
    let waypoints = stops.enumerated().map { index, stop in
        Waypoint(id: UUID(), tripID: UUID(), orderIndex: index, kind: stop.0, name: stop.1, coordinate: coordinate)
    }
    HStack(spacing: 16) {
        ForEach(waypoints) { waypoint in
            TripMapWaypointPinView(waypoint: waypoint)
        }
    }
    .padding()
}
