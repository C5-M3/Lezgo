//
//  RouteSummaryDrawer.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import SwiftUI

struct RouteSummaryDrawer: View {
    @Bindable var viewModel: MapViewModel

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Starting Point
                Section("Starting Point") {
                    Button {
                        viewModel.activeSelectionSheet = .start
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.circle.fill")
                                .foregroundStyle(.blue)
                            Text(viewModel.startPoint?.name ?? "Choose Starting Point...")
                                .font(.body)
                                .foregroundStyle(viewModel.startPoint == nil ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }

                // Section 2: Destination & Intermediate Stops
                Section("Destination") {
                    // Intermediate stops (rendered only if existing)
                    ForEach(Array(viewModel.intermediateStops.enumerated()), id: \.element.id) { index, stop in
                        HStack(spacing: 12) {
                            Image(systemName: "\(index + 1).circle.fill")
                                .foregroundStyle(.purple)

                            Button {
                                viewModel.activeSelectionSheet = .stop(index: index)
                            } label: {
                                Text(stop.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                viewModel.removeStop(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    // Only show "Add Stop" if the destination has been selected
                    if viewModel.destinationPoint != nil {
                        Button {
                            viewModel.addStop()
                        } label: {
                            Label("Add Stop", systemImage: "plus.circle")
                                .font(.body)
                        }
                    }

                    // Final destination point
                    Button {
                        viewModel.activeSelectionSheet = .destination
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                            Text(viewModel.destinationPoint?.name ?? "Where to?")
                                .font(.body)
                                .foregroundStyle(viewModel.destinationPoint == nil ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }

                // Section 3: Trip Progress / Summary
                if viewModel.isLoadingRoute {
                    HStack {
                        Spacer()
                        ProgressView("Calculating optimal route...")
                        Spacer()
                    }
                } else if let trip = viewModel.tripResult {
                    Section("Trip Summary") {
                        LabeledContent("Total Distance", value: String(format: "%.1f km", trip.totalDistance / 1000))
                        LabeledContent("Estimated Time", value: "\(Int(trip.totalDuration / 60)) min")
                    }
                }
            }
            .navigationTitle("Lezgo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
