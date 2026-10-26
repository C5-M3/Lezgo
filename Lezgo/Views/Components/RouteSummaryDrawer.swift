//
//  RouteSummaryDrawer.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import SwiftUI
import MapKit

struct RouteSummaryDrawer: View {
    @Bindable var viewModel: MapViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Route Details") {
                    Button {
                        viewModel.activeSelectionSheet = .start
                    } label: {
                        HStack {
                            Text("Start")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(viewModel.startPoint?.name ?? "Choose Start...")
                                .foregroundStyle(viewModel.startPoint == nil ? .secondary : .primary)
                                .lineLimit(1)
                        }
                    }

                    Button {
                        viewModel.activeSelectionSheet = .destination
                    } label: {
                        HStack {
                            Text("Destination")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(viewModel.destinationPoint?.name ?? "Choose Destination...")
                                .foregroundStyle(viewModel.destinationPoint == nil ? .secondary : .primary)
                                .lineLimit(1)
                        }
                    }
                }

                if viewModel.isLoadingRoute {
                    HStack {
                        Spacer()
                        ProgressView("Calculating optimal route...")
                        Spacer()
                    }
                } else if let route = viewModel.route {
                    Section("Trip Summary") {
                        LabeledContent("Distance", value: String(format: "%.1f km", route.distance / 1000))
                        LabeledContent("Estimated Time", value: "\(Int(route.expectedTravelTime / 60)) min")
                    }
                }
            }
            .navigationTitle("Lezgo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
