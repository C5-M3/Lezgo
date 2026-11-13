//
//  DraftTripView.swift
//  Lezgo
//
//  Created by Rizal Pratama on 27/10/26.
//

import MapKit
import SwiftUI
import UIKit

/// Full-screen prompt presented on launch when an active trip is found on device (US-03).
/// Allows the user to continue the existing trip or start a new one.
struct DraftTripView: View {
    @State private var viewModel: DraftTripViewModel
    let onContinueTrip: () -> Void
    let onNewTrip: () -> Void
    let onTripEnded: () -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var bottomContentHeight: CGFloat = 390
    @State private var primaryCoordinates: [CLLocationCoordinate2D] = []
    @State private var primaryDurationText: String = "37 min"

    private var primaryBadgeCoordinate: CLLocationCoordinate2D? {
        guard !primaryCoordinates.isEmpty else { return nil }
        let midIndex = primaryCoordinates.count / 2
        return primaryCoordinates[midIndex]
    }

    init(
        viewModel: DraftTripViewModel,
        onContinueTrip: @escaping () -> Void = {},
        onNewTrip: @escaping () -> Void = {},
        onTripEnded: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onContinueTrip = onContinueTrip
        self.onNewTrip = onNewTrip
        self.onTripEnded = onTripEnded
        let coords = viewModel.routeCoordinates.map(\.locationCoordinate)
        _primaryCoordinates = State(initialValue: coords)
        if let duration = viewModel.durationText {
            _primaryDurationText = State(initialValue: duration)
        }
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        GeometryReader { geometry in
            let topInset = Self.EffectiveTopInset(from: geometry)
            let bottomInset = Self.EffectiveBottomInset(from: geometry)

            ZStack {
                // Background Map showing the saved trip route (strictly visual, interaction disabled)
                MapView(
                    cameraPosition: $cameraPosition,
                    primaryCoordinates: primaryCoordinates,
                    primaryBadgeCoordinate: primaryBadgeCoordinate,
                    primaryDurationText: primaryDurationText,
                    startCoordinate: viewModel.startCoordinate,
                    destinationCoordinate: viewModel.destinationCoordinate,
                    destinationName: viewModel.destinationName
                )
                .allowsHitTesting(false)

                // Dark gradient fading from transparent over the map to black at the bottom
                GradientOverlay()
                    .allowsHitTesting(false)

                // Touch blocker: absorbs any tap/touch on the background/map area so it never leaks to HomeView
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Absorbs tap to prevent interactions with HomeView or background map
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHidden(true)

                // Foreground Content
                VStack(spacing: 0) {
                    Spacer()
                    BottomCard(
                        viewModel: viewModel,
                        bottomInset: bottomInset,
                        onContinueTrip: onContinueTrip
                    )
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
                        if newHeight > 0, abs(bottomContentHeight - newHeight) > 1 {
                            bottomContentHeight = newHeight
                            updateCamera(
                                size: geometry.size,
                                topInset: topInset,
                                animated: false
                            )
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .task {
                setupRoutes()
                updateCamera(
                    size: geometry.size,
                    topInset: topInset,
                    animated: false
                )
                if viewModel.routeCoordinates.isEmpty {
                    await fetchLiveRoutes()
                    updateCamera(
                        size: geometry.size,
                        topInset: topInset,
                        animated: true
                    )
                } else if viewModel.durationText == nil {
                    await fetchLiveDurationOnly()
                }
                let isOpen = await viewModel.CheckServerStatus()
                if !isOpen, !viewModel.wasCancelledByLeader {
                    onTripEnded()
                }
            }
            .onChange(of: viewModel.routeCoordinates) { _, newCoords in
                guard !newCoords.isEmpty else { return }
                primaryCoordinates = newCoords.map(\.locationCoordinate)
                updateCamera(
                    size: geometry.size,
                    topInset: topInset,
                    animated: true
                )
            }
            .onChange(of: viewModel.durationText) { _, newDuration in
                if let newDuration {
                    primaryDurationText = newDuration
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                updateCamera(
                    size: newSize,
                    topInset: topInset,
                    animated: false
                )
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .task {
            await viewModel.Listen()
        }
        .confirmDialog(
            isPresented: $bindableViewModel.isConfirmingNewTrip,
            title: Text(verbatim: viewModel.confirmTitle),
            message: viewModel.confirmMessage.map { Text(verbatim: $0) },
            cancelTitle: "Cancel",
            confirmTitle: "Create",
            // Only the leader's "Create" ends the current trip for everyone.
            isDestructive: viewModel.confirmMessage != nil,
            onConfirm: {
                Task {
                    if await viewModel.ConfirmNewTrip() {
                        onNewTrip()
                    }
                }
            }
        )
        .confirmDialog(
            isPresented: $bindableViewModel.wasCancelledByLeader,
            title: Text(verbatim: viewModel.cancelledTitle),
            message: Text(verbatim: viewModel.cancelledMessage),
            cancelTitle: nil,
            confirmTitle: "OK",
            onConfirm: onTripEnded
        )
    }

    // MARK: - Route & Camera Helpers

    private func setupRoutes() {
        if !viewModel.routeCoordinates.isEmpty {
            primaryCoordinates = viewModel.routeCoordinates.map(\.locationCoordinate)
        } else if let start = viewModel.startCoordinate?.locationCoordinate,
                  let dest = viewModel.destinationCoordinate?.locationCoordinate {
            primaryCoordinates = [start, dest]
        }

        if let duration = viewModel.durationText {
            primaryDurationText = duration
        }
    }

    private func fetchLiveRoutes() async {
        guard let start = viewModel.startCoordinate?.locationCoordinate,
              let dest = viewModel.destinationCoordinate?.locationCoordinate else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem.Make(at: start)
        request.destination = MKMapItem.Make(at: dest)
        request.transportType = .automobile

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            guard let fastest = response.routes.min(by: {
                $0.expectedTravelTime < $1.expectedTravelTime
            }) else { return }

            let pointCount = fastest.polyline.pointCount
            var primaryCoords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
            fastest.polyline.getCoordinates(&primaryCoords, range: NSRange(location: 0, length: pointCount))

            let primaryMin = max(1, Int(round(fastest.expectedTravelTime / 60)))
            self.primaryCoordinates = primaryCoords
            self.primaryDurationText = "\(primaryMin) min"
        } catch {
            // Keep default routes if directions query fails
        }
    }

    private func fetchLiveDurationOnly() async {
        guard let start = viewModel.startCoordinate?.locationCoordinate,
              let dest = viewModel.destinationCoordinate?.locationCoordinate else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem.Make(at: start)
        request.destination = MKMapItem.Make(at: dest)
        request.transportType = .automobile

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            guard let fastest = response.routes.min(by: {
                $0.expectedTravelTime < $1.expectedTravelTime
            }) else { return }
            let primaryMin = max(1, Int(round(fastest.expectedTravelTime / 60)))
            self.primaryDurationText = "\(primaryMin) min"
        } catch {
            // Keep existing duration text
        }
    }

    private func updateCamera(size: CGSize, topInset: CGFloat, animated: Bool = false) {
        var allCoords: [CLLocationCoordinate2D] = []
        if let start = viewModel.startCoordinate {
            allCoords.append(start.locationCoordinate)
        }
        allCoords.append(contentsOf: primaryCoordinates)
        if let dest = viewModel.destinationCoordinate {
            allCoords.append(dest.locationCoordinate)
        }

        let rect = Self.ComputeTargetMapRect(
            coordinates: allCoords,
            bottomContentHeight: bottomContentHeight,
            size: size,
            topInset: topInset
        )
        let position = MapCameraPosition.rect(rect)
        if animated {
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = position
            }
        } else {
            cameraPosition = position
        }
    }
}

// `sample` is debug-only (ADR 0018), so the preview is too; without the guard the Release build fails.
#if DEBUG
#Preview {
    DraftTripView(
        viewModel: .sample,
        onContinueTrip: {},
        onNewTrip: {},
        onTripEnded: {}
    )
}
#endif
