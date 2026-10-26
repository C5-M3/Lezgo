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
    @State private var selectedDetent: PresentationDetent = .fraction(0.28)

    var body: some View {
        @Bindable var boundViewModel = viewModel

        Map(position: $boundViewModel.cameraPosition) {
            UserAnnotation()

            // Custom start marker if not GPS default
            if let start = viewModel.startPoint, start.name != "Current Location" {
                Marker(start.name, coordinate: start.coordinate)
                    .tint(.blue)
            }

            // Intermediate Stop Markers
            ForEach(Array(viewModel.intermediateStops.enumerated()), id: \.element.id) { index, stop in
                Marker("\(index + 1). \(stop.name)", systemImage: "\(index + 1).circle", coordinate: stop.coordinate)
                    .tint(.purple)
            }

            // Destination Marker
            if let destination = viewModel.destinationPoint {
                Marker(destination.name, coordinate: destination.coordinate)
                    .tint(.red)
            }

            // Multi-segment polyline path
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
            RouteSummaryDrawer(viewModel: boundViewModel)
                .sheet(item: $boundViewModel.activeSelectionSheet) { sheetType in
                    LocationSearchSheet(viewModel: boundViewModel, selectionType: sheetType)
                }
                .presentationDetents([.fraction(0.28), .medium], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.28)))
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

