//
//  HomeView.swift
//  Lezgo
//
//  Created by Rizal Pratama on 24/10/26.
//

import MapKit
import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $viewModel.cameraPosition) {
                UserAnnotation()

                if let selectedMapItem = viewModel.selectedMapItem {
                    Marker(
                        selectedMapItem.name ?? "Destinasi",
                        coordinate: selectedMapItem.location.coordinate
                    )
                    .tint(.blue)
                }

                ForEach(viewModel.searchResults, id: \.self) { item in
                    if item != viewModel.selectedMapItem {
                        Marker(
                            item.name ?? "Lokasi",
                            coordinate: item.location.coordinate
                        )
                        .tint(.red)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            .mapControlVisibility(.visible)

            if isSearchFocused {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        isSearchFocused = false
                        hideKeyboard()
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Tutup pencarian")
            }

            locationInfoCard
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            if isSearchFocused {
                viewModel.onSearchTextChanged(newValue, isFocused: true)
            }
        }
        .onChange(of: viewModel.mapService.userLocation) { _, newLocation in
            viewModel.onUserLocationChanged(newLocation)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var locationInfoCard: some View {
        VStack(spacing: 12) {
            if viewModel.isLocationAccessDenied {
                HStack(spacing: 12) {
                    Image(systemName: "location.slash.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Akses Lokasi Ditolak")
                            .font(.headline)
                        Text("Aktifkan izin lokasi pada Pengaturan untuk melihat posisi saat ini.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else if viewModel.isLoadingLocation {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Mencari posisi perangkat...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }

            TravelMapControlsView(
                searchText: $viewModel.searchText,
                suggestions: viewModel.suggestions,
                isSearching: viewModel.isSearching,
                isFocused: $isSearchFocused,
                onDoorTapped: {
                    isSearchFocused = false
                    hideKeyboard()
                    viewModel.resetSearchAndCenterOnUser()
                },
                onSearch: {
                    performSearch()
                },
                onSubmit: {
                    performSearch()
                },
                onSelectSuggestion: { suggestion in
                    selectSuggestion(suggestion)
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Actions

    private func performSearch() {
        isSearchFocused = false
        hideKeyboard()
        Task {
            await viewModel.performSearch()
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        isSearchFocused = false
        hideKeyboard()
        Task {
            await viewModel.selectSuggestion(suggestion)
        }
    }
}

#Preview {
    HomeView()
}
