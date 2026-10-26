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
    @State private var selectedDetent: PresentationDetent = .fraction(0.24)

    var body: some View {
        @Bindable var boundViewModel = viewModel

        Map(position: $boundViewModel.cameraPosition) {
            UserAnnotation()

            if let start = viewModel.startPoint {
                Marker(start.name, coordinate: start.coordinate)
                    .tint(.blue)
            }

            if let destination = viewModel.destinationPoint {
                Marker(destination.name, coordinate: destination.coordinate)
                    .tint(.red)
            }

            if let route = viewModel.route {
                MapPolyline(route.polyline)
                    .stroke(.tint, lineWidth: 6)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        // Persistent bottom sheet drawer
        .sheet(isPresented: .constant(true)) {
            RouteSummaryDrawer(viewModel: boundViewModel)
                .sheet(item: $boundViewModel.activeSelectionSheet) { sheetType in
                    LocationSearchSheet(viewModel: boundViewModel, selectionType: sheetType)
                }
                .presentationDetents([.fraction(0.24), .medium], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.24)))
                .interactiveDismissDisabled()
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
