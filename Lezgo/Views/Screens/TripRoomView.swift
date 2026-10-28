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

    @State private var showingInviteSheet = false
    @State private var showingLeaveConfirmation = false
    @State private var showingStartTripConfirmation = false
    @State private var showingRemoveConfirmation = false
    @State private var showingSetLeaderSheet = false
    @State private var participantToKick: Participant?
    @State private var participantToSetLeader: Participant?
    @State private var participantToEdit: Participant?
    @Environment(\.dismiss) private var dismiss

    init(tripID: UUID, myParticipantID: UUID) {
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self._viewModel = State(initialValue: nil)
    }

    init(viewModel: TripRoomViewModel) {
        self.tripID = viewModel.tripID
        self.myParticipantID = viewModel.myParticipantID
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
                    tripService: tripService, tripID: tripID, myParticipantID: myParticipantID
                )
            }
            await viewModel?.Listen()
        }
    }

    private func lobbyView(viewModel: TripRoomViewModel) -> some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(
                    viewModel: viewModel, onLeave: { showingLeaveConfirmation = true },
                    onSetLeader: { showingSetLeaderSheet = true }
                ).padding(.bottom, 8)

                List {
                    RouteSectionView(waypoints: viewModel.waypoints)
                    TripRoomParticipantsSection(
                        viewModel: viewModel,
                        onKick: { participantToKick = $0 },
                        onSetLeader: { participantToSetLeader = $0 },
                        onEdit: { participantToEdit = $0 },
                        onInvite: { showingInviteSheet = true }
                    )
                }
                .listStyle(.insetGrouped).scrollContentBackground(.hidden)

                BottomActionView(
                    viewModel: viewModel, onStartTrip: { showingStartTripConfirmation = true },
                    onRemove: { showingRemoveConfirmation = true }
                ).padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
        .navigationBarBackButtonHidden(true)
        .modifier(TripRoomAlertsModifier(
            viewModel: viewModel,
            showingLeave: $showingLeaveConfirmation,
            showingStart: $showingStartTripConfirmation,
            showingRemove: $showingRemoveConfirmation,
            participantToKick: $participantToKick,
            participantToSetLeader: $participantToSetLeader,
            dismissAction: { dismiss() }
        ))
        .tripRoomSheets(
            viewModel: viewModel,
            showingInvite: $showingInviteSheet,
            showingSetLeader: $showingSetLeaderSheet,
            participantToEdit: $participantToEdit
        )
    }
}

// MARK: - Sheets

private extension View {
    func tripRoomSheets(
        viewModel: TripRoomViewModel,
        showingInvite: Binding<Bool>,
        showingSetLeader: Binding<Bool>,
        participantToEdit: Binding<Participant?>
    ) -> some View {
        sheet(isPresented: showingInvite) {
            InviteSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: showingSetLeader) {
            SetLeaderSheetView(viewModel: viewModel) { candidate in
                Task {
                    do {
                        try await viewModel.SetLeader(to: candidate)
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .sheet(item: participantToEdit) { _ in
            EditProfileSheetView(viewModel: viewModel)
        }
    }
}

// MARK: - Subviews

private struct TopBarView: View {
    let viewModel: TripRoomViewModel
    let onLeave: () -> Void
    let onSetLeader: () -> Void

    var body: some View {
        HStack {
            if viewModel.isSelectionMode {
                Button(viewModel.selectAllButtonTitle, action: viewModel.SelectAll)
                    .font(.subheadline.weight(.medium)).foregroundStyle(.primary).padding(.horizontal, 16)
                    .frame(height: 44).background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                    .buttonStyle(.plain)
            } else {
                Button(action: onLeave) {
                    Image(systemName: "iphone.and.arrow.forward.outward")
                        .rotationEffect(.degrees(180)).circleBarButtonStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isCurrentUserLeader ? "End trip" : "Leave trip room")
            }
            Spacer()
            if viewModel.isSelectionMode {
                Button(action: viewModel.ToggleSelectionMode) { Image(systemName: "checkmark").circleBarButtonStyle() }
                    .buttonStyle(.plain).accessibilityLabel("Done selecting")
            } else if viewModel.isCurrentUserLeader {
                Menu {
                    Button("Select", action: viewModel.ToggleSelectionMode)
                    Button("Set leader", action: onSetLeader)
                } label: { Image(systemName: "ellipsis").circleBarButtonStyle() }
                .buttonStyle(.plain).accessibilityLabel("Room options")
            }
        }.padding(.horizontal, 16)
    }
}

private extension View {
    func circleBarButtonStyle() -> some View {
        font(.system(size: 18, weight: .semibold)).foregroundStyle(.primary)
            .frame(width: 44, height: 44).background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
            .accessibilityHidden(true)
    }
}

private struct RouteSectionView: View {
    let waypoints: [Waypoint]

    var body: some View {
        Section("Route Trip") {
            ForEach(waypoints) { waypoint in
                HStack(spacing: 12) {
                    Image(systemName: waypoint.kind.iconName)
                        .font(waypoint.kind == .checkpoint ? .system(size: 8) : .system(size: 16, weight: .semibold))
                        .foregroundStyle(waypoint.kind == .checkpoint ? .secondary : .primary)
                        .frame(width: 20, height: 20).accessibilityHidden(true)
                    Text(waypoint.name).font(.body).lineLimit(2)
                    Spacer()
                }
                .padding(.vertical, 4).accessibilityElement(children: .combine)
                .accessibilityLabel("\(waypoint.kind.accessibilityPrefix): \(waypoint.name)")
            }
        }
    }
}

private extension WaypointKind {
    var iconName: String {
        switch self {
        case .start: return "house.fill"
        case .checkpoint: return "circle.fill"
        case .destination: return "mappin.and.ellipse"
        }
    }

    var accessibilityPrefix: String {
        switch self {
        case .start: return "Starting point"
        case .checkpoint: return "Checkpoint"
        case .destination: return "Destination"
        }
    }
}

private struct BottomActionView: View {
    let viewModel: TripRoomViewModel
    let onStartTrip: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if viewModel.isSelectionMode {
            HStack {
                Spacer()
                Button("Remove", action: onRemove)
                    .font(.headline).foregroundStyle(viewModel.canRemove ? .primary : .secondary)
                    .padding(.horizontal, 24).frame(height: 44).buttonStyle(.plain).disabled(!viewModel.canRemove)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground).opacity(viewModel.canRemove ? 1 : 0.6),
                        in: Capsule()
                    )
                    .accessibilityLabel("Remove selected participants")
            }
        } else {
            VStack(spacing: 6) {
                if viewModel.isCurrentUserLeader {
                    Button("Start Trip", action: onStartTrip)
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canStartTrip)
                        .accessibilityLabel("Start Trip")

                    if !viewModel.canStartTrip {
                        Text("Invite at least one friend to start.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Waiting for others ...")
                        .font(.subheadline)
                }
            }
            .font(.headline)
            .foregroundStyle(viewModel.canStartTrip || !viewModel.isCurrentUserLeader ? .primary : .secondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
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
        initialState: SampleTrip.State(status: .lobby)
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
        initialState: SampleTrip.State(status: .lobby)
    )
    TripRoomView(viewModel: viewModel)
        .environment(\.tripService, service)
}
#endif
