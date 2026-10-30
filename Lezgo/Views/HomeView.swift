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
    @State private var mapViewModel = MapViewModel()
    @State private var isJoinTripPresented: Bool = false
    @State private var isSetRoutePresented: Bool = false
    @State private var drawerHeight: CGFloat = 310
    @State private var selectedDetent: PresentationDetent = .height(280)

    var body: some View {
        @Bindable var boundMapViewModel = mapViewModel

        MapReader { proxy in
            ZStack(alignment: .bottom) {
                Map(
                    position: isSetRoutePresented ? $boundMapViewModel.cameraPosition : $viewModel.cameraPosition,
                    interactionModes: isJoinTripPresented ? [] : .all
                ) {
                    UserAnnotation()

                    if isSetRoutePresented {
                        if let start = mapViewModel.startPoint, start.name != "Current Location" {
                            Marker(start.name, coordinate: start.coordinate)
                                .tint(.blue)
                        }

                        ForEach(Array(mapViewModel.destinations.enumerated()), id: \.element.id) { index, point in
                            if mapViewModel.destinations.count == 1 || index == mapViewModel.destinations.count - 1 {
                                Marker(point.name, coordinate: point.coordinate)
                                    .tint(.red)
                            } else {
                                Marker(
                                    "\(index + 1). \(point.name)",
                                    systemImage: "\(index + 1).circle",
                                    coordinate: point.coordinate
                                )
                                .tint(.purple)
                            }
                        }

                        // Alternative routes for each leg (yellow)
                        ForEach(mapViewModel.routeLegs) { leg in
                            ForEach(Array(leg.routes.enumerated()), id: \.offset) { routeIndex, route in
                                if routeIndex != leg.selectedRouteIndex {
                                    MapPolyline(route.polyline)
                                        .stroke(Color.yellow.opacity(0.88), lineWidth: 5)
                                }
                            }
                        }

                        // Selected route for each leg (highlighted blue tint)
                        ForEach(mapViewModel.selectedPolylines, id: \.self) { polyline in
                            MapPolyline(polyline)
                                .stroke(.tint, lineWidth: 6)
                        }
                    } else {
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
                }
                .onTapGesture { screenPoint in
                    if isSetRoutePresented, let coord = proxy.convert(screenPoint, from: .local) {
                        mapViewModel.selectNearestRoute(to: coord, drawerHeight: drawerHeight)
                    }
                }
                .accessibilityAddTraits(.isButton)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                    MapPitchToggle()
                }
                .mapControlVisibility(isJoinTripPresented ? .hidden : .visible)
                .disabled(isJoinTripPresented)
                .allowsHitTesting(!isJoinTripPresented)

                // Menyembunyikan seluruh kontrol pencarian dan tombol room saat pop up aktif
                if !isJoinTripPresented && !isSetRoutePresented {
                    locationInfoCard
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .overlay {
            // Pop up modal Apple HIG component untuk memasukkan room code
            if isJoinTripPresented {
                JoinTripView(
                    isPresented: $isJoinTripPresented,
                    viewModel: JoinTripViewModel(roomCode: viewModel.inviteRoomCode ?? ""),
                    onEnter: { code in
                        Task {
                            _ = await viewModel.JoinTrip(roomCode: code, tripService: tripService)
                        }
                    }
                )
                // A second invite link while the dialog is open replaces the code instead of keeping the old one.
                .id(viewModel.inviteRoomCode)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94)),
                    removal: .identity
                ))
                // Above the Draft Road Trip screen, so an invite link opened during another trip is still seen.
                .zIndex(300)
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
        .sheet(
            isPresented: $isSetRoutePresented,
            onDismiss: {
                handleSetRouteDismissed()
            },
            content: {
                SetRouteSheet(
                    viewModel: mapViewModel,
                    isFullPresentation: selectedDetent == .large,
                    onBack: {
                        handleSetRouteDismissed()
                        isSetRoutePresented = false
                    },
                    onExpand: {
                        withAnimation {
                            selectedDetent = .large
                        }
                    }
                )
                .sheet(item: $boundMapViewModel.activeSelectionSheet) { sheetType in
                    LocationSearchSheet(viewModel: mapViewModel, selectionType: sheetType)
                }
                .presentationDetents(
                    [.height(drawerHeight), .large],
                    selection: $selectedDetent
                )
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(drawerHeight)))
                .interactiveDismissDisabled(mapViewModel.hasPlanChanges)
            }
        )
        .onAppear {
            viewModel.onAppear()
        }
        // Universal links (https://lezgo-trip.netlify.app/join) and older lezgo:// links both arrive here (ADR 0020).
        .onOpenURL { url in
            if viewModel.OpenInviteLink(url) {
                isJoinTripPresented = true
            }
        }
        .onChange(of: isJoinTripPresented) { _, isPresented in
            if !isPresented {
                viewModel.inviteRoomCode = nil
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
                onDoorTapped: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isJoinTripPresented = true
                    }
                },
                onTap: {
                    navigateToSetRoute()
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Actions

    private func navigateToSetRoute() {
        mapViewModel.onAppear()
        isSetRoutePresented = true
    }

    private func handleSetRouteDismissed() {
        mapViewModel.clearDestinationSearch()
        viewModel.resetSearchAndCenterOnUser()
    }
}

#Preview {
    HomeView()
}
