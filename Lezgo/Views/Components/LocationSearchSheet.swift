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
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Current Location")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("Use GPS position")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
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

                Section(selectionType == .start ? "Search Places" : "") {
                    ForEach(viewModel.searchService.searchResults, id: \.self) { result in
                        Button {
                            viewModel.selectSearchResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(selectionType.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: selectionType == .start ? "Change start location" : "Where to?"
            )
            .onChange(of: viewModel.searchQuery) { _, newValue in
                viewModel.onSearchQueryChanged(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.searchQuery = ""
                        viewModel.searchService.updateQueryFragment("")
                        dismiss()
                    }
                }
            }
        }
    }
}
