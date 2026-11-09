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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = HomeViewModel()
    @State private var mapViewModel = MapViewModel()
    @State private var isJoinTripPresented: Bool = false
    @State private var pendingJoinedSession: TripSession?
    @State private var isSetRoutePresented: Bool = false

    private let cardDarkBackground = Color(red: 28/255, green: 28/255, blue: 30/255)

    private var shouldHideHomeControls: Bool {
        viewModel.isTransitioningToTripMap || viewModel.isReturningToTripRoom
            || viewModel.activeTripSession != nil || viewModel.activeMapSession != nil
    }

    var body: some View {
        @Bindable var boundHomeViewModel = viewModel

        ZStack {
            Color(.tripCard)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .padding(.top, 120)
                    .padding(.horizontal, 24)

                cardsSection
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                Spacer(minLength: 16)

                MascotsView()
            }
        }
        .preferredColorScheme(.dark)
        .overlay {
            transitionOverlay
            draftTripOverlay
        }
        .sheet(
            isPresented: $isJoinTripPresented,
            onDismiss: {
                if let session = pendingJoinedSession {
                    pendingJoinedSession = nil
                    viewModel.onTripJoined(session)
                }
            },
            content: {
                JoinTripView(
                    isPresented: $isJoinTripPresented,
                    viewModel: JoinTripViewModel(
                        roomCode: viewModel.inviteRoomCode ?? "",
                        tripService: tripService,
                        storage: viewModel.activeTripStorage
                    ),
                    onNavigateToTripRoom: { session in
                        pendingJoinedSession = session
                    }
                )
            }
        )
        .fullScreenCover(isPresented: $isSetRoutePresented) {
            SetRouteView(
                viewModel: mapViewModel,
                onBack: {
                    handleSetRouteDismissed()
                    isSetRoutePresented = false
                },
                onTripCreated: { session in
                    isSetRoutePresented = false
                    viewModel.onTripJoined(session)
                },
                onDismiss: {
                    handleSetRouteDismissed()
                    isSetRoutePresented = false
                }
            )
        }
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
                        activeTripStorage: viewModel.activeTripStorage,
                        locationSharer: LocationSharer(
                            tripService: tripService,
                            tripID: session.state.trip.id,
                            participantID: session.myParticipantID
                        )
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
                    onClose: { viewModel.onMapSessionClosed() },
                    onReturnToTripRoom: { viewModel.onReturnedToTripRoom($0) }
                )
            }
        )
        .modifier(Prompts(viewModel: viewModel))
        .onAppear { viewModel.onAppear() }
        // Universal invite links and the older `lezgo://join` links both arrive here (US-02).
        .onOpenURL { url in viewModel.OpenInviteLink(url) }
        .onChange(of: viewModel.inviteRoomCode) { _, roomCode in
            guard roomCode != nil else { return }
            isJoinTripPresented = true
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
}

// MARK: - Header & Cards

private extension HomeView {
    @ViewBuilder
    var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image("LezgoIcon")
                .resizable()
                .scaledToFit()
                .frame(height: 42)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Make and lead a trip or join one !")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    var cardsSection: some View {
        VStack(spacing: 16) {
            leadTripCard
            joinTripCard
        }
    }

    @ViewBuilder
    var leadTripCard: some View {
        Button {
            navigateToSetRoute()
        } label: {
            ZStack(alignment: .trailing) {
                // Mascot watermark on the right side
                Image("LeadTripMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)
                    .offset(y: 15)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 54) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(.black)
                                .frame(width: 50, height: 50)

                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.brandYellow)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.black)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Lead a trip")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.black)

                        Text("Plan the trip and make a room for friends to join trip!")
                            .font(.subheadline)
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .background(Color.brandYellow)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var joinTripCard: some View {
        Button {
            isJoinTripPresented = true
        } label: {
            ZStack(alignment: .trailing) {
                // Mascot watermark on the right side
                Image("JoinTripMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .offset(x: -10, y: -8)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 54) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(Color.brandYellow)
                                .frame(width: 50, height: 50)

                            Image(systemName: "door.left.hand.open")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.black)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color(white: 0.6))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Join a trip")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)

                        Text("Got a room code from friend leader? Join the room now!")
                            .font(.subheadline)
                            .foregroundStyle(Color(white: 0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .background(cardDarkBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overlays & Logic

private extension HomeView {
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
                    withAnimation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion)) {
                        viewModel.ClearActiveDraftTrip()
                    }
                },
                onTripEnded: {
                    withAnimation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion)) {
                        viewModel.handleDraftTripEnded()
                    }
                }
            )
            .transition(.opacity)
            .zIndex(200)
        }
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
