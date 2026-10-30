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

    private var shouldHideHomeControls: Bool {
        viewModel.isTransitioningToTripMap || viewModel.activeTripSession != nil || viewModel.activeMapSession != nil
    }

    var body: some View {
        @Bindable var boundHomeViewModel = viewModel

        MapReader { proxy in
            ZStack(alignment: .bottom) {
                mapView(proxy: proxy)

                if !isJoinTripPresented && !isSetRoutePresented && !shouldHideHomeControls {
                    locationInfoCard
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .overlay {
            transitionOverlay
            joinTripOverlay
            draftTripOverlay
        }
        .sheet(
            isPresented: $isSetRoutePresented,
            onDismiss: { handleSetRouteDismissed() },
            content: { setRouteSheet() }
        )
        .fullScreenCover(
            item: $boundHomeViewModel.activeTripSession,
            onDismiss: {
                viewModel.activeTripSession = nil
                viewModel.CheckActiveDraftTrip()
            },
            content: { session in
                TripRoomView(
                    viewModel: TripRoomViewModel(
                        tripService: tripService,
                        tripID: session.state.trip.id,
                        myParticipantID: session.myParticipantID,
                        initialState: session.state,
                        activeTripStorage: viewModel.activeTripStorage
                    ),
                    onTripStarted: { viewModel.onTripStartedFromRoom(session: session) }
                )
            }
        )
        .fullScreenCover(
            item: $boundHomeViewModel.activeMapSession,
            onDismiss: { viewModel.onMapSessionClosed() },
            content: { session in
                TripMapView(
                    viewModel: TripMapViewModel(
                        session: session,
                        tripService: tripService,
                        activeTripStorage: viewModel.activeTripStorage
                    ),
                    onNewDestination: {},
                    onClose: { viewModel.onMapSessionClosed() }
                )
            }
        )
        .safeAreaInset(edge: .top) { topNoticeInset }
        .onAppear { viewModel.onAppear() }
        // Universal invite links and the older `lezgo://join` links both arrive here (US-02).
        .onOpenURL { url in viewModel.OpenInviteLink(url) }
        .onChange(of: viewModel.inviteRoomCode) { _, roomCode in
            guard roomCode != nil else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isJoinTripPresented = true
            }
        }
        .onChange(of: isJoinTripPresented) { _, isPresented in
            if !isPresented { viewModel.inviteRoomCode = nil }
        }
        .onChange(of: viewModel.mapService.userLocation) { _, newLocation in
            viewModel.onUserLocationChanged(newLocation)
        }
    }
}

// MARK: - Subviews & Actions

private extension HomeView {
    @ViewBuilder
    func mapView(proxy: MapProxy) -> some View {
        @Bindable var boundMapViewModel = mapViewModel
        @Bindable var boundViewModel = viewModel

        Map(
            position: isSetRoutePresented ? $boundMapViewModel.cameraPosition : $boundViewModel.cameraPosition,
            interactionModes: isJoinTripPresented ? [] : .all
        ) {
            UserAnnotation()
            if isSetRoutePresented {
                routeContent
            } else {
                searchContent
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
        .mapControlVisibility((isJoinTripPresented || shouldHideHomeControls) ? .hidden : .visible)
        .disabled(isJoinTripPresented || shouldHideHomeControls)
        .allowsHitTesting(!isJoinTripPresented && !shouldHideHomeControls)
    }

    @MapContentBuilder
    var routeContent: some MapContent {
        if let start = mapViewModel.startPoint, start.name != "Current Location" {
            Marker(start.name, coordinate: start.coordinate)
                .tint(.blue)
        }

        ForEach(Array(mapViewModel.destinations.enumerated()), id: \.element.id) { index, point in
            if mapViewModel.destinations.count == 1 || index == mapViewModel.destinations.count - 1 {
                Marker(point.name, coordinate: point.coordinate)
                    .tint(.red)
            } else {
                Marker("\(index + 1). \(point.name)", systemImage: "\(index + 1).circle", coordinate: point.coordinate)
                    .tint(.purple)
            }
        }

        ForEach(mapViewModel.routeLegs) { leg in
            ForEach(Array(leg.routes.enumerated()), id: \.offset) { routeIndex, route in
                if routeIndex != leg.selectedRouteIndex {
                    MapPolyline(route.polyline)
                        .stroke(Color.yellow.opacity(0.88), lineWidth: 5)
                }
            }
        }

        ForEach(mapViewModel.selectedPolylines, id: \.self) { polyline in
            MapPolyline(polyline)
                .stroke(.tint, lineWidth: 6)
        }
    }

    @MapContentBuilder
    var searchContent: some MapContent {
        if let selectedMapItem = viewModel.selectedMapItem {
            Marker(selectedMapItem.name ?? "Destinasi", coordinate: selectedMapItem.location.coordinate)
                .tint(.blue)
        }

        ForEach(viewModel.searchResults, id: \.self) { item in
            if item != viewModel.selectedMapItem {
                Marker(item.name ?? "Lokasi", coordinate: item.location.coordinate)
                    .tint(.red)
            }
        }
    }

    @ViewBuilder
    var transitionOverlay: some View {
        if viewModel.isTransitioningToTripMap {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .overlay {
                    ProgressView()
                        .scaleEffect(1.2)
                }
                .transition(.opacity)
                .zIndex(150)
        }
    }

    @ViewBuilder
    var joinTripOverlay: some View {
        if isJoinTripPresented {
            JoinTripView(
                isPresented: $isJoinTripPresented,
                viewModel: JoinTripViewModel(
                    roomCode: viewModel.inviteRoomCode ?? "",
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
    }

    @ViewBuilder
    var draftTripOverlay: some View {
        if !shouldHideHomeControls,
           let activeDraft = viewModel.activeDraftTrip,
           viewModel.activeTripSession == nil {
            DraftTripView(
                viewModel: DraftTripViewModel(
                    summary: activeDraft,
                    tripService: tripService,
                    storage: viewModel.activeTripStorage
                ),
                onContinueTrip: {
                    Task {
                        await viewModel.continueDraftTrip(tripService: tripService)
                    }
                },
                onNewTrip: {
                    withAnimation {
                        viewModel.ClearActiveDraftTrip()
                    }
                },
                onTripEnded: {
                    withAnimation {
                        viewModel.handleDraftTripEnded()
                    }
                }
            )
            .transition(.opacity)
            .zIndex(200)
        }
    }

    @ViewBuilder
    func setRouteSheet() -> some View {
        @Bindable var boundMapViewModel = mapViewModel
        SetRouteSheet(
            viewModel: mapViewModel,
            isFullPresentation: selectedDetent == .large,
            onBack: {
                handleSetRouteDismissed()
                isSetRoutePresented = false
            },
            onTripCreated: { session in
                isSetRoutePresented = false
                viewModel.onTripJoined(session)
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

    @ViewBuilder
    var topNoticeInset: some View {
        if !shouldHideHomeControls, let notice = viewModel.lastTripEndedNotice {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                Text(notice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.lastTripEndedNotice = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.formationAlertBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    var locationInfoCard: some View {
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

    func navigateToSetRoute() {
        mapViewModel.onAppear()
        isSetRoutePresented = true
    }

    func handleSetRouteDismissed() {
        mapViewModel.clearDestinationSearch()
        viewModel.resetSearchAndCenterOnUser()
    }
}

#Preview {
    HomeView()
}
