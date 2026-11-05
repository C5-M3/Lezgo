//
//  TripRoomMapPreview.swift
//  Lezgo
//
//  Created by oky faishal on 05/11/26.
//

import MapKit
import SwiftUI

/// The map at the top of the Trip Room: the start point, the destination and the road between them, nothing else
/// (`specs/UserStories.md` → US-04, "Room"). It only shows the plan, so it does not move with a finger.
struct TripRoomMapPreview: View {
    let start: Waypoint?
    let destination: Waypoint?
    let polyline: [Coordinate]
    /// Off at the accessibility text sizes: MapKit draws the names at that size and they run off the edge. The
    /// Overview under the map says the same names in text that scales.
    var showsNames = true

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: []) {
            if polyline.count > 1 {
                MapPolyline(coordinates: polyline.map(\.locationCoordinate))
                    .stroke(Color(.brandBlue), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            if let start {
                Annotation(start.name, coordinate: start.coordinate.locationCoordinate) {
                    Circle()
                        .fill(Color(.brandBlue))
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 18, height: 18)
                }
                .annotationTitles(showsNames ? .automatic : .hidden)
            }
            if let destination {
                Marker(
                    destination.name,
                    systemImage: "flag.checkered",
                    coordinate: destination.coordinate.locationCoordinate
                )
                .tint(Color(.brandYellow))
                .annotationTitles(showsNames ? .automatic : .hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let start, let destination else { return String(localized: "Route map") }
        return String(localized: "Route map from \(start.name) to \(destination.name)")
    }
}

#if DEBUG
#Preview("Route") {
    let state = SampleTrip.State(status: .lobby)
    TripRoomMapPreview(
        start: state.waypoints.first,
        destination: state.waypoints.last,
        polyline: state.route?.polyline ?? []
    )
    .frame(height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Loading") {
    TripRoomMapPreview(start: nil, destination: nil, polyline: [])
        .frame(height: 300)
        .preferredColorScheme(.dark)
}
#endif
