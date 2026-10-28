//
//  HomeView.swift
//  Lezgo
//
//  Created by Rizal Pratama on 24/10/26.
//

import MapKit
import SwiftUI

struct HomeView: View {
    @Environment(\.tripService) private var tripService
    @State private var viewModel = HomeViewModel()
    @State private var isJoinTripPresented: Bool = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(
                position: $viewModel.cameraPosition,
                interactionModes: isJoinTripPresented ? [] : .all
            ) {
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
            .mapControlVisibility(isJoinTripPresented ? .hidden : .visible)
            .disabled(isJoinTripPresented)
            .allowsHitTesting(!isJoinTripPresented)

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

            // Menyembunyikan seluruh kontrol pencarian dan tombol room saat pop up aktif
            if !isJoinTripPresented {
                locationInfoCard
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .overlay {
            // Pop up modal Apple HIG component untuk memasukkan room code
            if isJoinTripPresented {
                JoinTripView(
                    isPresented: $isJoinTripPresented,
                    viewModel: JoinTripViewModel(
                        tripService: tripService,
                        storage: viewModel.activeTripStorage
                    ),
                    onNavigateToTripRoom: { session in
                        viewModel.onTripJoined(session)
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94)),
                    removal: .identity
                ))
                .zIndex(100)
            }

            // Draft Road Trip screen when an unfinished trip is present (US-03)
            if let activeDraft = viewModel.activeDraftTrip {
                DraftTripView(
                    viewModel: DraftTripViewModel(
                        summary: activeDraft,
                        tripService: tripService,
                        storage: viewModel.activeTripStorage
                    ),
                    onContinueTrip: {
                        // "Continue Trip" opens the Trip Room (LOBBY) or map (IN_TRIP)
                    },
                    onNewTrip: {
                        withAnimation {
                            viewModel.ClearActiveDraftTrip()
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(200)
            }
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
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isJoinTripPresented = true
                    }
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
