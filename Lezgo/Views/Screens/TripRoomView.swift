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
    @State private var participantToEdit: Participant?
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
                if let viewModel {
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
            onEdit: { participantToEdit = $0 },
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isTransitioning)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showingStartTripConfirmation)
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .modifier(TripRoomAlertsModifier(
            viewModel: viewModel,
            showingLeave: $showingLeaveConfirmation,
            dismissAction: { dismiss() }
        ))
        .sheet(isPresented: $showingInviteSheet) {
            InviteSheetView(viewModel: viewModel)
        }
        .sheet(item: $participantToEdit) { participant in
            EditProfileSheetView(viewModel: viewModel, participant: participant)
        }
        // The hi-fi is dark only: BrandYellow text has no contrast on a light background (US-04, "Room").
        .preferredColorScheme(.dark)
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

/// Everything that scrolls: the map with the title, the overview, the participants and End Trip or Exit Trip.
private struct TripRoomContent: View {
    let viewModel: TripRoomViewModel
    let isTransitioning: Bool
    let onEdit: (Participant) -> Void
    let onInvite: () -> Void
    let onLeave: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TripRoomHeader(viewModel: viewModel)
                VStack(alignment: .leading, spacing: 28) {
                    if viewModel.isLocationImprecise { PreciseLocationNotice() }
                    TripRoomOverview(
                        startName: viewModel.startPoint?.name,
                        destinationName: viewModel.destination?.name,
                        numberOfStops: viewModel.numberOfStops
                    )
                    TripRoomParticipantsSection(
                        viewModel: viewModel,
                        isTransitioning: isTransitioning,
                        onEdit: onEdit,
                        onInvite: onInvite
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
