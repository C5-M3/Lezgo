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
            StartActionView(viewModel: viewModel, isTransitioning: isTransitioning) {
                showingStartTripConfirmation = true
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.black)
        }
        .overlay {
            if showingStartTripConfirmation {
                StartTripDialog(
                    title: viewModel.startTripConfirmationTitle,
                    onCancel: { showingStartTripConfirmation = false },
                    onStart: { StartTrip(viewModel) }
                )
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isTransitioning)
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
        showingStartTripConfirmation = false
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
                        LeaveButton(viewModel: viewModel, action: onLeave)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .ignoresSafeArea(edges: .top)
        .background(.black)
    }
}

/// The map preview with "Lez Get Ready !" on its lower edge, fading into the black page like the hi-fi.
private struct TripRoomHeader: View {
    let viewModel: TripRoomViewModel
    /// Fixed, not scaled with Dynamic Type: at large text sizes the map would push the overview off the screen.
    private let mapHeight: CGFloat = 320

    var body: some View {
        TripRoomMapPreview(
            start: viewModel.startPoint,
            destination: viewModel.destination,
            polyline: viewModel.routePolyline
        )
        .frame(height: mapHeight)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: mapHeight / 2)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            Text("Lez Get Ready !")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(Color(.brandYellow))
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// "End Trip" for the leader, "Exit Trip" for a member, under the participants (US-07, "Leave and end").
private struct LeaveButton: View {
    let viewModel: TripRoomViewModel
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(viewModel.isCurrentUserLeader ? "End Trip" : "Exit Trip")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(viewModel.isLeaving)
    }
}

/// "Start Trip" for the leader, "Waiting for others ..." for a member, and "Starting Trip..." once it starts.
private struct StartActionView: View {
    let viewModel: TripRoomViewModel
    let isTransitioning: Bool
    let onStartTrip: () -> Void

    var body: some View {
        if isTransitioning {
            HStack(spacing: 12) {
                ProgressView()
                Text("Starting Trip...")
            }
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
        } else if viewModel.isCurrentUserLeader {
            VStack(spacing: 6) {
                Button(action: onStartTrip) {
                    Text("Start Trip")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color(.brandYellow).opacity(viewModel.canStartTrip ? 1 : 0.4), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canStartTrip)
                if !viewModel.canStartTrip {
                    Text("Invite at least one friend to start.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Waiting for others ...")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        }
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
