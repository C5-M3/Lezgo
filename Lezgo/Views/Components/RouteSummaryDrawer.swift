//
//  RouteSummaryDrawer.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import SwiftUI

struct RouteSummaryDrawer: View {
    @Bindable var viewModel: MapViewModel
    var onHeightChanged: (CGFloat) -> Void

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

                    if viewModel.destinationPoint != nil {
                        Button {
                            viewModel.addStop()
                        } label: {
                            Label("Add Stop", systemImage: "plus.circle")
                                .font(.body)
                        }
                    }

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

                // Section 3: Summary Metrics
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
            .scrollDisabled(true) // Keeps form tightly fitted to its content rows
            .readHeight { calculatedHeight in
                // Add top navigation bar buffer (~44pt)
                onHeightChanged(calculatedHeight + 50)
            }
            .navigationTitle("Lezgo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

