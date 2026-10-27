//
//  RouteSummaryDrawer.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import SwiftUI

struct RouteSummaryDrawer: View {
    @Bindable var viewModel: MapViewModel
    var isFullPresentation: Bool = false
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
                            Image(systemName: "location.fill")
                                .foregroundStyle(.secondary)
                            Text(viewModel.startPoint?.name ?? "Choose Starting Point...")
                                .font(.body)
                                .foregroundStyle(viewModel.startPoint == nil ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Section 2: Destinations (unified hierarchy)
                Section("Destinations") {
                    ForEach(Array(viewModel.destinations.enumerated()), id: \.element.id) { index, point in
                        HStack(spacing: 12) {
                            Image(systemName: "mappin")
                                .foregroundStyle(.secondary)

                            Button {
                                viewModel.activeSelectionSheet = .destination(index: index)
                            } label: {
                                Text(point.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.removeDestination(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        if isFullPresentation {
                            viewModel.moveDestination(fromOffsets: fromOffsets, toOffset: toOffset)
                        }
                    }

                    Button {
                        viewModel.addDestination()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                            Text("Add...")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Section 3: Summary Metrics (shown only when pulled to full)
                if isFullPresentation {
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
            }
            .environment(\.editMode, isFullPresentation && viewModel.destinations.count > 1 ? .constant(.active) : .constant(.inactive))
            .readHeight { calculatedHeight in
                // Add top navigation bar buffer (~44pt)
                onHeightChanged(calculatedHeight + 50)
            }
            .navigationTitle("Set Route")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
