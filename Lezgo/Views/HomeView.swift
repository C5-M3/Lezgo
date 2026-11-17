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
    @State private var pendingJoinedSession: TripSession?
    @State private var isTripHistoryPresented: Bool = false
    /// Set Route is built once Home has settled, hidden, so its map is ready before LEAD runs into it.
    @State private var isSetRoutePrepared = false
    /// What Siri hands over inside the app (US-08): a joined trip or a plan link.
    private let siriHandoff = SiriHandoff.shared

    private var shouldHideHomeControls: Bool {
        viewModel.isTransitioningToTripMap || viewModel.isReturningToTripRoom
            || viewModel.activeTripSession != nil || viewModel.activeMapSession != nil
    }

    var body: some View {
        @Bindable var boundHomeViewModel = viewModel

        HomeSplitStage(
            flow: viewModel.splitFlow,
            progress: viewModel.splitProgress,
            destination: viewModel.splitDestination,
            isMoving: viewModel.isSplitMoving,
            stepStart: viewModel.splitStepStart,
            preparesLeadScreen: isSetRoutePrepared,
            onLead: OpenSetRoute,
            onJoin: { RunSplit(viewModel.JoinTapped()) },
            leadScreen: { setRouteScreen },
            joinScreen: { joinTripScreen }
        )
        .preferredColorScheme(.dark)
        .overlay {
            transitionOverlay
            draftTripOverlay
            tripHistoryOverlay
        }
        .fullScreenCover(isPresented: $isTripHistoryPresented) {
            TripRecapView()
        }
        .fullScreenCover(
            item: $boundHomeViewModel.activeTripSession,
            onDismiss: {
                viewModel.activeTripSession = nil
                viewModel.CheckActiveDraftTrip()
                Task { await viewModel.RefreshActiveTrip(tripService: tripService) }
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
        .modifier(Prompts(viewModel: viewModel, onConfirmContinue: ContinueDraftTrip))
        .onAppear { viewModel.onAppear() }
        .task { await viewModel.RefreshActiveTrip(tripService: tripService) }
        .task {
            // After Home's first frames, so building Set Route's map does not hold up the launch.
            try? await Task.sleep(for: .milliseconds(500))
            isSetRoutePrepared = true
        }
        // Universal invite links and the older `lezgo://join` links both arrive here (US-02).
        .onOpenURL { url in
            viewModel.OpenInviteLink(url)
            // "Create a trip" from Siri arrives as `lezgo://plan?to=…` (US-08).
            viewModel.OpenPlanLink(url)
        }
        // "Create a trip" from Siri hands its link over here (US-08); a cold start finds it waiting.
        .onChange(of: siriHandoff.pendingLink, initial: true) {
            guard let link = siriHandoff.TakeLink() else { return }
            viewModel.OpenPlanLink(link)
        }
        // "Join a trip" from Siri has already joined: open its Trip Room (US-08).
        .onChange(of: siriHandoff.pendingJoin, initial: true) {
            guard let session = siriHandoff.TakeJoin() else { return }
            SiriLog.Note("Join a trip: Home opens the joined trip")
            viewModel.onTripJoined(session)
        }
        .onChange(of: viewModel.plannedDestination) { _, destination in
            guard let destination else { return }
            mapViewModel.onAppear(searchingFor: destination)
            viewModel.ShowSplitDestination(.lead)
            viewModel.plannedDestination = nil
        }
        .onChange(of: viewModel.inviteRoomCode) { _, roomCode in
            guard roomCode != nil, viewModel.splitDestination != .join else { return }
            viewModel.ShowSplitDestination(.join)
        }
        .onChange(of: viewModel.mapService.userLocation) { _, newLocation in
            viewModel.onUserLocationChanged(newLocation)
        }
    }
}

// MARK: - Split Home

private extension HomeView {
    var setRouteScreen: some View {
        SetRouteView(
            viewModel: mapViewModel,
            onBack: CloseSetRoute,
            onTripCreated: { session in
                // The route now belongs to the trip; the next new trip starts from an empty plan.
                handleSetRouteDismissed()
                viewModel.ResetSplit()
                viewModel.onTripJoined(session)
            },
            onDismiss: CloseSetRoute
        )
    }

    var joinTripScreen: some View {
        JoinTripView(
            isPresented: joinTripIsPresented,
            viewModel: JoinTripViewModel(
                roomCode: viewModel.inviteRoomCode ?? "",
                tripService: tripService,
                storage: viewModel.activeTripStorage
            ),
            incomingRoomCode: viewModel.inviteRoomCode,
            onNavigateToTripRoom: { session in
                pendingJoinedSession = session
            },
            onClose: {
                RunSplit(viewModel.BackTapped()) {
                    viewModel.inviteRoomCode = nil
                }
            }
        )
    }

    /// Enter room code sets this to `false` once it has joined; Home then hands the trip over.
    var joinTripIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.splitDestination == .join },
            set: { isPresented in
                if !isPresented { FinishJoin() }
            }
        )
    }

    func OpenSetRoute() {
        let steps = viewModel.LeadTapped()
        guard !steps.isEmpty else { return }
        // LEAD on the JOIN home only swings back; Set Route opens on the next tap.
        if steps.last?.flow == .lead {
            isSetRoutePrepared = true
            mapViewModel.onAppear()
        }
        RunSplit(steps)
    }

    func CloseSetRoute() {
        RunSplit(viewModel.BackTapped(), then: handleSetRouteDismissed)
    }

    func FinishJoin() {
        viewModel.inviteRoomCode = nil
        viewModel.ResetSplit()
        if let session = pendingJoinedSession {
            pendingJoinedSession = nil
            viewModel.onTripJoined(session)
        }
    }

    /// Plays the split's steps one after another. A tap during the motion gives no steps and is ignored.
    func RunSplit(_ steps: [HomeSplitMotion.Step], then finish: @escaping () -> Void = {}) {
        guard !steps.isEmpty else { return }
        PlaySplitStep(steps[...], then: finish)
    }

    func PlaySplitStep(_ steps: ArraySlice<HomeSplitMotion.Step>, then finish: @escaping () -> Void) {
        guard let step = steps.first else {
            viewModel.FinishSplitMotion()
            finish()
            return
        }
        // Every flow shares the LEAD home at 0 and the JOIN home at `joinHome`, so a step goes on from where the
        // last one stopped.
        let start = viewModel.splitProgress
        let duration = HomeSplitMotion.Duration(of: step.flow, from: start, to: step.target)
        // With Reduce Motion each step is a short fade; the halves jump and the next screen fades in or out.
        let animation = reduceMotion ? Animation.lezgoFade : .linear(duration: duration)
        withAnimation(animation) {
            viewModel.BeginSplitStep(step)
        } completion: {
            withAnimation(reduceMotion ? .lezgoFade : nil) {
                viewModel.FinishSplitStep(step)
            }
            PlaySplitStep(steps.dropFirst(), then: finish)
        }
    }
}

// MARK: - Overlays & Logic

private extension HomeView {
    @ViewBuilder
    var tripHistoryOverlay: some View {
        if !shouldHideHomeControls, viewModel.splitDestination == nil {
            VStack {
                HStack {
                    Spacer()
                    Button("Trip History", systemImage: "clock.arrow.circlepath") {
                        isTripHistoryPresented = true
                    }
                    .labelStyle(.iconOnly)
                    .font(.callout.weight(.bold))
                    .lezgoGlassButton(.roundOnYellow)
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }
                Spacer()
            }
            .zIndex(100)
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
                    viewModel.RequestContinue()
                    if viewModel.isConfirmingContinue == false { ContinueDraftTrip() }
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

    /// Takes the saved trip over on this phone (ADR 0031).
    func ContinueDraftTrip() {
        Task {
            await viewModel.continueDraftTrip(tripService: tripService)
        }
    }

    func handleSetRouteDismissed() {
        mapViewModel.clearDestinationSearch()
        viewModel.resetSearchAndCenterOnUser()
    }
}

#Preview {
    HomeView()
}
