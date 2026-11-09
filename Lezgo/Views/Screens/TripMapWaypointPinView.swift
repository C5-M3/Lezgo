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
        Image(systemName: Symbol())
            .font(.title)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.background, .tint)
            .frame(minWidth: 44, minHeight: 44)
            // A map graphic: keep it from covering the route at the largest text sizes.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: waypoint.name))
            .accessibilityValue(Text(Kind()))
    }

    private func Symbol() -> String {
        switch waypoint.kind {
        case .start: return "circle.circle.fill"
        case .checkpoint: return "mappin.circle.fill"
        case .destination: return "flag.circle.fill"
        }
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
