//
//  MainMapScreen.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import SwiftUI
import MapKit

struct MainMapScreen: View {
    @State private var viewModel = MapViewModel()
    @State private var drawerHeight: CGFloat = 280

    var body: some View {
        @Bindable var boundViewModel = viewModel

        Map(position: $boundViewModel.cameraPosition) {
            UserAnnotation()

            if let start = viewModel.startPoint, start.name != "Current Location" {
                Marker(start.name, coordinate: start.coordinate)
                    .tint(.blue)
            }

            ForEach(Array(viewModel.intermediateStops.enumerated()), id: \.element.id) { index, stop in
                Marker("\(index + 1). \(stop.name)", systemImage: "\(index + 1).circle", coordinate: stop.coordinate)
                    .tint(.purple)
            }

            if let destination = viewModel.destinationPoint {
                Marker(destination.name, coordinate: destination.coordinate)
                    .tint(.red)
            }

            if let trip = viewModel.tripResult {
                MapPolyline(trip.combinedPolyline)
                    .stroke(.tint, lineWidth: 6)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .sheet(isPresented: .constant(true)) {
            RouteSummaryDrawer(viewModel: boundViewModel) { newHeight in
                if abs(self.drawerHeight - newHeight) > 10 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.drawerHeight = max(240, min(newHeight, 520))
                    }
                    viewModel.adjustCameraToFitRoute(bottomPadding: self.drawerHeight)
                }
            }
            .sheet(item: $boundViewModel.activeSelectionSheet) { sheetType in
                LocationSearchSheet(viewModel: boundViewModel, selectionType: sheetType)
            }
            // Dynamically tracks the exact computed height
            .presentationDetents([.height(drawerHeight)])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(drawerHeight)))
            .interactiveDismissDisabled()
        }
        .onAppear {
            viewModel.onAppear()
        }
        .alert("Notice", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    MainMapScreen()
}

