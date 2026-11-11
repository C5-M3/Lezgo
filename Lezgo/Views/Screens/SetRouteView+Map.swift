//
//  SetRouteView+Map.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 11/11/26.
//

import MapKit
import SwiftUI

// MARK: - Map

extension SetRouteView {
    var mapVignetteOverlay: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.4),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)

            Spacer()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 240)
        }
    }

    @ViewBuilder
    var mapSection: some View {
        @Bindable var boundViewModel = viewModel
        MapReader { proxy in
            Map(
                position: $boundViewModel.cameraPosition,
                interactionModes: [.pan, .zoom]
            ) {
                UserAnnotation()

                RoutePlanMapContent(viewModel: viewModel)
            }
            .onTapGesture { screenPoint in
                if let coord = proxy.convert(screenPoint, from: .local) {
                    viewModel.selectNearestRoute(to: coord, drawerHeight: 180)
                }
            }
            .accessibilityAddTraits(.isButton)
            .mapControls { }
            // The map runs under the cards; its safe area is the space between them, where MapKit frames the route.
            .safeAreaPadding(mapInsets)
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            mapFrame = frame
        }
    }

    var isShowingMetricsCard: Bool {
        viewModel.hasRoute || viewModel.isLoadingRoute
    }

    /// The parts of the map covered by the collapsed route card and the metrics card, plus a small gap.
    var mapInsets: EdgeInsets {
        let gap: CGFloat = 12
        let top = max(collapsedRouteControlsBottom - mapFrame.minY, 0) + gap
        let bottom = isShowingMetricsCard ? max(mapFrame.maxY - metricsCardTop, 0) + gap : gap
        return EdgeInsets(top: top, leading: gap, bottom: bottom, trailing: gap)
    }

    /// Keeps the card's latest bottom edge while it shows its collapsed rows, not while searching or showing every
    /// stop.
    func RememberCollapsedRouteControls() {
        guard !viewModel.isSearching, !isStopsExpanded else { return }
        collapsedRouteControlsBottom = routeControlsBottom
    }
}
