//
//  RoutePlanMapContent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import MapKit
import SwiftUI

/// What the route planners draw on their map, as in the hi-fi ("S3 Set Route · Preview"): the leader's robot at the
/// start, a white pin for each stop on the way, the yellow flag at the destination, the chosen route in blue and the
/// other routes paler behind it. The chosen route is joined to its pins, so it never stops short of them.
struct RoutePlanMapContent: MapContent {
    let viewModel: MapViewModel

    /// The robot's image has transparent margins, so it is drawn larger than the space it takes.
    private static let robotSize = 64.0

    var body: some MapContent {
        ForEach(viewModel.routeLegs) { leg in
            ForEach(Array(leg.routes.enumerated()), id: \.offset) { routeIndex, route in
                if routeIndex != leg.selectedRouteIndex {
                    MapPolyline(route.polyline)
                        .stroke(Color(.brandBlue).opacity(0.35), style: Self.LineStyle(width: 6))
                }
            }
        }

        ForEach(Array(viewModel.selectedRouteLines.enumerated()), id: \.offset) { _, line in
            MapPolyline(coordinates: line.map(\.locationCoordinate))
                .stroke(Color(.brandBlue), style: Self.LineStyle(width: 6))
        }

        if let start = viewModel.startPoint {
            Annotation(start.name, coordinate: start.coordinate) {
                Image(.ontripNoglowYellow)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.robotSize, height: Self.robotSize)
                    .accessibilityHidden(true)
            }
            .annotationTitles(.hidden)
        }

        ForEach(Array(viewModel.destinations.enumerated()), id: \.element.id) { index, point in
            let isDestination = index == viewModel.destinations.count - 1
            Annotation(point.name, coordinate: point.coordinate) {
                RouteStopPin(kind: isDestination ? .destination : .checkpoint)
            }
            // Only the destination is named, as in the hi-fi; the stops' names are in the list above the map.
            .annotationTitles(isDestination ? .automatic : .hidden)
        }
    }

    private static func LineStyle(width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}
