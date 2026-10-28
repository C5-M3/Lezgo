//
//  LocationSearchSheet.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//

import SwiftUI
import MapKit

struct LocationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MapViewModel
    let selectionType: ActivePointSelection
    @State private var isSearchPresented: Bool = false

    var body: some View {
        NavigationStack {
            List {
                // If editing the start point, offer a 1-tap "Current Location" reset option
                if selectionType == .start && viewModel.locationService.userLocation != nil {
                    Section {
                        Button {
                            viewModel.selectCurrentLocationAsStart()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .accessibilityHidden(true)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Current Location")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("Use GPS position")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.searchService.isSearching {
                    HStack {
                        Spacer()
                        ProgressView("Searching places...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                if viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Search for a Place",
                        systemImage: "magnifyingglass",
                        description: Text("Start typing an address or place name to find locations.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if !viewModel.searchService.isSearching && viewModel.searchService.searchResults.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    Section(selectionType == .start ? "Search Places" : "") {
                        ForEach(viewModel.searchService.searchResults, id: \.self) { result in
                            Button {
                                viewModel.selectSearchResult(result)
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(result.title)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    if let meters = result.distanceInMeters {
                                        let distText = meters >= 1000
                                            ? String(format: "%.1f km", meters / 1000.0)
                                            : String(format: "%.0f m", meters)
                                        Text(distText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .transition(.opacity)
                                    } else if result.isCalculatingDistance {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 44, height: 14)
                                            .redacted(reason: .placeholder)
                                            .transition(.opacity)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.25), value: result.distanceInMeters)
                        }
                    }
                }
            }
            .navigationTitle(selectionType.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: selectionType == .start ? "Change start location" : "Where to?"
            )
            .onChange(of: viewModel.searchQuery) { _, newValue in
                viewModel.onSearchQueryChanged(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isSearchPresented = false
                        viewModel.searchQuery = ""
                        viewModel.searchService.updateQueryFragment("")
                        dismiss()
                    }
                }
            }
            .task {
                isSearchPresented = true
            }
        }
    }
}
