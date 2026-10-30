//
//  SetRouteMapView.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//

import SwiftUI
import MapKit

struct SetRouteMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MapViewModel
    @State private var drawerHeight: CGFloat = 310
    @State private var selectedDetent: PresentationDetent = .height(280)

    private let title: LocalizedStringResource
    private let nextTitle: LocalizedStringResource
    /// When `nil`, Back clears the plan and closes the planner (Set Route); Edit Route passes its own.
    private let onBack: (() -> Void)?
    private let onNext: (() -> Void)?
    private let onDismiss: (() -> Void)?
    private let isBackDisabled: Bool
    private let isNextDisabled: Bool
    private let isStartPointLocked: Bool

    init(
        viewModel: MapViewModel = MapViewModel(),
        title: LocalizedStringResource = "Set Route",
        nextTitle: LocalizedStringResource = "Next",
        onBack: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        isBackDisabled: Bool = false,
        isNextDisabled: Bool = false,
        isStartPointLocked: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
        self.nextTitle = nextTitle
        self.onBack = onBack
        self.onNext = onNext
        self.onDismiss = onDismiss
        self.isBackDisabled = isBackDisabled
        self.isNextDisabled = isNextDisabled
        self.isStartPointLocked = isStartPointLocked
    }

    var body: some View {
        @Bindable var boundViewModel = viewModel

        MapReader { proxy in
            Map(position: $boundViewModel.cameraPosition) {
                UserAnnotation()

                if let start = viewModel.startPoint, start.name != String(localized: .waypointCurrentLocation) {
                    Marker(start.name, coordinate: start.coordinate)
                        .tint(.blue)
                }

                ForEach(Array(viewModel.destinations.enumerated()), id: \.element.id) { index, point in
                    if viewModel.destinations.count == 1 || index == viewModel.destinations.count - 1 {
                        Marker(point.name, coordinate: point.coordinate)
                            .tint(.red)
                    } else {
                        Marker(
                            "\(index + 1). \(point.name)",
                            systemImage: "\(index + 1).circle",
                            coordinate: point.coordinate
                        )
                        .tint(.purple)
                    }
                }

                // Alternative routes for each leg (yellow)
                ForEach(viewModel.routeLegs) { leg in
                    ForEach(Array(leg.routes.enumerated()), id: \.offset) { routeIndex, route in
                        if routeIndex != leg.selectedRouteIndex {
                            MapPolyline(route.polyline)
                                .stroke(Color.yellow.opacity(0.88), lineWidth: 5)
                        }
                    }
                }

                // Selected route for each leg (highlighted blue tint)
                ForEach(viewModel.selectedPolylines, id: \.self) { polyline in
                    MapPolyline(polyline)
                        .stroke(.tint, lineWidth: 6)
                }
            }
            .onTapGesture { screenPoint in
                if let coord = proxy.convert(screenPoint, from: .local) {
                    viewModel.selectNearestRoute(to: coord, drawerHeight: drawerHeight)
                }
            }
            .accessibilityAddTraits(.isButton)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
        }
        .sheet(isPresented: .constant(true)) {
            SetRouteSheet(
                viewModel: boundViewModel,
                isFullPresentation: selectedDetent == .large,
                title: title,
                nextTitle: nextTitle,
                onBack: onBack ?? ClearAndClose,
                onNext: onNext,
                onExpand: {
                    withAnimation {
                        selectedDetent = .large
                    }
                },
                isBackDisabled: isBackDisabled,
                isNextDisabled: isNextDisabled,
                isStartPointLocked: isStartPointLocked
            )
            .sheet(item: $boundViewModel.activeSelectionSheet) { sheetType in
                LocationSearchSheet(
                    viewModel: boundViewModel,
                    selectionType: sheetType,
                    autoFocus: !CommandLine.arguments.contains("-ui-testing-set-route-map")
                )
            }
            // Only compact (height) and full (large) — no half pulls
            .presentationDetents(
                [.height(drawerHeight), .large],
                selection: $selectedDetent
            )
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(drawerHeight)))
            .interactiveDismissDisabled()
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    private func ClearAndClose() {
        viewModel.clearDestinationSearch()
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

#Preview {
    SetRouteMapView()
}
