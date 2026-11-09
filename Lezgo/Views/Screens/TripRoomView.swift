//
//  TripRoomView.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

@MainActor
struct TripRoomView: View {
    @Environment(\.tripService) private var tripService
    @State private var viewModel: TripRoomViewModel?
    private let tripID: UUID
    private let myParticipantID: UUID
    /// `nil` uses the phone's saved trip; simulated screens pass one in memory.
    private let activeTripStorage: (any ActiveTripStorage)?
    private let onTripStarted: () -> Void
    @State private var hasFiredTripStarted = false

    @State private var showingInviteSheet = false
    @State private var showingLeaveConfirmation = false
    @State private var showingStartTripConfirmation = false
    @State private var heldParticipant: Participant?
    @Namespace private var avatarNamespace
    @State private var participantToEdit: Participant?
    @State private var participantToRemove: Participant?
    @State private var participantToMakeLeader: Participant?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        tripID: UUID,
        myParticipantID: UUID,
        activeTripStorage: (any ActiveTripStorage)? = nil,
        onTripStarted: @escaping () -> Void = {}
    ) {
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.activeTripStorage = activeTripStorage
        self.onTripStarted = onTripStarted
        self._viewModel = State(initialValue: nil)
    }

    init(viewModel: TripRoomViewModel, onTripStarted: @escaping () -> Void = {}) {
        self.tripID = viewModel.tripID
        self.myParticipantID = viewModel.myParticipantID
        self.activeTripStorage = nil
        self.onTripStarted = onTripStarted
        self._viewModel = State(initialValue: viewModel)
    }

    #if DEBUG
    init() { self.init(tripID: SampleTrip.tripID, myParticipantID: SampleTrip.agusID) }
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel, viewModel.state != nil {
                    lobbyView(viewModel: viewModel)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = TripRoomViewModel(
                    tripService: tripService,
                    tripID: tripID,
                    myParticipantID: myParticipantID,
                    activeTripStorage: activeTripStorage,
                    locationSharer: LocationSharer(
                        tripService: tripService,
                        tripID: tripID,
                        participantID: myParticipantID
                    )
                )
            }
            await viewModel?.Listen()
        }
        .onChange(of: viewModel?.hasTripStarted, initial: true) { _, hasStarted in
            if hasStarted == true && !hasFiredTripStarted {
                hasFiredTripStarted = true
                onTripStarted()
            }
        }
    }

    private var isTransitioning: Bool {
        viewModel?.isStartingTrip == true || viewModel?.hasTripStarted == true || hasFiredTripStarted
    }

    private func lobbyView(viewModel: TripRoomViewModel) -> some View {
        TripRoomContent(
            viewModel: viewModel,
            isTransitioning: isTransitioning,
            heldParticipantID: heldParticipant?.id,
            avatarNamespace: avatarNamespace,
            onHold: { Hold($0) },
            onInvite: { showingInviteSheet = true },
            onLeave: { showingLeaveConfirmation = true }
        )
        .safeAreaInset(edge: .bottom) {
            TripRoomStartAction(viewModel: viewModel, isTransitioning: isTransitioning) {
                showingStartTripConfirmation = true
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.black)
        }
        .overlay { heldAvatarOverlay(viewModel: viewModel) }
        .sensoryFeedback(.impact, trigger: heldParticipant?.id)
        .confirmDialog(
            isPresented: $showingStartTripConfirmation,
            title: Text(verbatim: viewModel.startTripConfirmationTitle),
            onConfirm: { StartTrip(viewModel) },
            confirm: {
                Image(.lezgoBlack)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                    .accessibilityLabel("Start")
            }
        )
        .animation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion), value: isTransitioning)
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .modifier(TripRoomAlertsModifier(
            viewModel: viewModel,
            showingLeave: $showingLeaveConfirmation,
            participantToRemove: $participantToRemove,
            participantToMakeLeader: $participantToMakeLeader,
            dismissAction: { dismiss() }
        ))
        .sheet(isPresented: $showingInviteSheet) {
            InviteSheetView(viewModel: viewModel)
        }
        .sheet(item: $participantToEdit) { participant in
            EditProfileSheetView(viewModel: viewModel, participant: participant)
        }
        .modifier(EditRouteCover(viewModel: viewModel))
        // The hi-fi is dark only: BrandYellow text has no contrast on a light background (US-04, "Room").
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func heldAvatarOverlay(viewModel: TripRoomViewModel) -> some View {
        if let participant = heldParticipant {
            HeldAvatarOverlay(
                participant: participant,
                displayName: viewModel.DisplayName(of: participant),
                actions: viewModel.ManagementActions(for: participant),
                avatarNamespace: avatarNamespace,
                onSelect: { action in
                    Release()
                    switch action {
                    case .setLeader: participantToMakeLeader = participant
                    case .editDetails: participantToEdit = participant
                    case .remove: participantToRemove = participant
                    }
                },
                onDismiss: { Release() }
            )
            .transition(.opacity)
        }
    }

    /// The avatar flies to the middle of the screen; without motion it just appears there.
    private func Hold(_ participant: Participant) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.2)) { heldParticipant = participant }
    }

    private func Release() {
        withAnimation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion)) { heldParticipant = nil }
    }

    private func StartTrip(_ viewModel: TripRoomViewModel) {
        Task {
            do {
                try await viewModel.StartTrip()
            } catch {
                viewModel.ShowError(error)
            }
        }
    }
}

// MARK: - Subviews

/// The route planner the leader opens with "Edit": on screen exactly while the view model has one, so Back and Save
/// close it there too.
private struct EditRouteCover: ViewModifier {
    let viewModel: TripRoomViewModel

    func body(content: Content) -> some View {
        content.fullScreenCover(
            item: Binding(get: { viewModel.editRoute }, set: { _ in viewModel.CloseEditRoute() })
        ) { editRoute in
            EditRouteView(viewModel: editRoute, onClose: viewModel.CloseEditRoute)
        }
    }
}

/// Everything that scrolls: the map with the title, the overview, the participants and End Trip or Exit Trip.
private struct TripRoomContent: View {
    let viewModel: TripRoomViewModel
    let isTransitioning: Bool
    let heldParticipantID: UUID?
    let avatarNamespace: Namespace.ID
    let onHold: (Participant) -> Void
    let onInvite: () -> Void
    let onLeave: () -> Void

    /// "Edit" is only there for the leader.
    private var editAction: (() -> Void)? {
        guard viewModel.canEditRoute else { return nil }
        return { viewModel.RequestEditRoute() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TripRoomHeader(viewModel: viewModel)
                VStack(alignment: .leading, spacing: 28) {
                    if viewModel.isLocationImprecise { PreciseLocationNotice() }
                    TripRoomOverview(
                        startName: viewModel.startPoint?.name,
                        destinationName: viewModel.destination?.name,
                        numberOfStops: viewModel.numberOfStops,
                        onEdit: editAction
                    )
                    TripRoomParticipantsSection(
                        viewModel: viewModel,
                        isTransitioning: isTransitioning,
                        onHold: onHold,
                        onInvite: onInvite,
                        heldParticipantID: heldParticipantID,
                        avatarNamespace: avatarNamespace
                    )
                    if !isTransitioning {
                        TripRoomLeaveButton(viewModel: viewModel, action: onLeave)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(.black)
    }
}

#if DEBUG
#Preview("Leader") {
    let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
    let viewModel = TripRoomViewModel(
        tripService: service,
        tripID: SampleTrip.tripID,
        myParticipantID: SampleTrip.agusID,
        initialState: SampleTrip.State(status: .lobby),
        activeTripStorage: SimulatedActiveTripStorage()
    )
    TripRoomView(viewModel: viewModel)
        .environment(\.tripService, service)
}

#Preview("Member") {
    let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
    let viewModel = TripRoomViewModel(
        tripService: service,
        tripID: SampleTrip.tripID,
        myParticipantID: SampleTrip.budiID,
        initialState: SampleTrip.State(status: .lobby),
        activeTripStorage: SimulatedActiveTripStorage()
    )
    TripRoomView(viewModel: viewModel)
        .environment(\.tripService, service)
}

#Preview("Member, Accessibility XXXL") {
    let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
    let viewModel = TripRoomViewModel(
        tripService: service,
        tripID: SampleTrip.tripID,
        myParticipantID: SampleTrip.budiID,
        initialState: SampleTrip.State(status: .lobby),
        activeTripStorage: SimulatedActiveTripStorage()
    )
    TripRoomView(viewModel: viewModel)
        .environment(\.tripService, service)
        .dynamicTypeSize(.accessibility5)
}
#endif
