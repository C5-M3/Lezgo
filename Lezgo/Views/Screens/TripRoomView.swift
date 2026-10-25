import SwiftUI

@MainActor
public struct TripRoomView: View {
    @State private var viewModel: TripRoomViewModel
    @State private var showingInviteSheet = false
    @State private var showingLeaveConfirmation = false
    @State private var showingStartTripConfirmation = false
    @State private var showingRemoveConfirmation = false
    @State private var showingSetLeaderSheet = false
    @State private var participantToKick: Participant?
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: TripRoomViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public init() {
        self.init(viewModel: TripRoomViewModel())
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 20) {
                    TopBarView(
                        viewModel: viewModel,
                        onLeave: { showingLeaveConfirmation = true },
                        onSetLeader: { showingSetLeaderSheet = true }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Route Trip").font(.headline)
                                RouteCardView(stops: viewModel.routeStops)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Participants").font(.headline)
                                    Spacer()
                                    Button {
                                        showingInviteSheet = true
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                            .frame(width: 32, height: 32)
                                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                                            .clipShape(.rect(cornerRadius: 8)).accessibilityHidden(true)
                                    }
                                    .buttonStyle(.plain).frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("Invite participant")
                                }

                                ParticipantsCardView(viewModel: viewModel, onKick: { participantToKick = $0 })
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    BottomActionView(
                        viewModel: viewModel,
                        onStartTrip: { showingStartTripConfirmation = true },
                        onRemove: { showingRemoveConfirmation = true }
                    )
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }
            }
            .navigationBarBackButtonHidden(true)
            .confirmationDialog("Leave Trip Room?", isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
                Button("Leave Trip Room", role: .destructive) { viewModel.LeaveRoom(); dismiss() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Leaving without handing over the lead will end the trip for everyone.")
            }
            .alert("Start trip?", isPresented: $showingStartTripConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Start") { viewModel.StartTrip() }
            }
            .alert(viewModel.removeConfirmationTitle, isPresented: $showingRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) { viewModel.RemoveSelectedParticipants() }
            }
            .alert(
                viewModel.RemoveParticipantConfirmationTitle(
                    for: participantToKick ?? Participant(name: "", description: "")
                ),
                isPresented: Binding(get: { participantToKick != nil }, set: { if !$0 { participantToKick = nil } })
            ) {
                Button("Cancel", role: .cancel) { participantToKick = nil }
                Button("Remove", role: .destructive) {
                    if let member = participantToKick {
                        viewModel.RemoveParticipant(id: member.id)
                        participantToKick = nil
                    }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                InviteSheetView(roomCode: viewModel.roomCode, inviteURL: viewModel.inviteURL)
            }
            .sheet(isPresented: $showingSetLeaderSheet) {
                SetLeaderSheetView(participants: viewModel.participants, onSelectLeader: viewModel.SetLeader(to:))
            }
        }
    }
}

// MARK: - Local Subviews

private struct TopBarView: View {
    let viewModel: TripRoomViewModel
    let onLeave: () -> Void
    let onSetLeader: () -> Void

    var body: some View {
        HStack {
            if viewModel.isSelectionMode {
                Button(viewModel.selectAllButtonTitle, action: viewModel.SelectAll)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
            } else {
                Button(action: onLeave) {
                    Image(systemName: "door.left.hand.open").circleBarButtonStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Leave trip room")
            }

            Spacer()

            if viewModel.isSelectionMode {
                Button(action: viewModel.ToggleSelectionMode) {
                    Image(systemName: "checkmark").circleBarButtonStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done selecting")
            } else {
                Menu {
                    Button("Select", action: viewModel.ToggleSelectionMode)
                    Button("Set leader", action: onSetLeader)
                } label: {
                    Image(systemName: "ellipsis").circleBarButtonStyle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Room options")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private extension View {
    func circleBarButtonStyle() -> some View {
        font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

private struct RouteCardView: View {
    let stops: [TripRoomViewModel.RouteStop]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: 12) {
                    Image(systemName: stop.kind.iconName)
                        .font(stop.kind == .checkpoint ? .system(size: 8) : .system(size: 16, weight: .semibold))
                        .foregroundStyle(stop.kind == .checkpoint ? .secondary : .primary)
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)

                    Text(stop.name).font(.body).lineLimit(2)
                    Spacer()
                }
                .padding(.vertical, 14).padding(.horizontal, 16)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stop.kind.accessibilityPrefix): \(stop.name)")
                if index < stops.count - 1 { Divider().padding(.leading, 48) }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

private struct ParticipantsCardView: View {
    let viewModel: TripRoomViewModel
    let onKick: (Participant) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.participants.isEmpty {
                Text("No participants yet").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 24)
            } else {
                ForEach(Array(viewModel.participants.enumerated()), id: \.element.id) { index, participant in
                    ParticipantRowView(
                        participant: participant,
                        isSelectionMode: viewModel.isSelectionMode,
                        isSelected: viewModel.selectedParticipantIds.contains(participant.id),
                        canSwipeToKick: viewModel.CanKick(participant: participant),
                        onToggleSelection: { viewModel.ToggleParticipantSelection(id: participant.id) },
                        onKick: { onKick(participant) }
                    )
                    if index < viewModel.participants.count - 1 {
                        Divider().padding(.leading, viewModel.isSelectionMode ? 92 : 56)
                    }
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

private struct ParticipantRowView: View {
    let participant: Participant
    let isSelectionMode: Bool
    let isSelected: Bool
    let canSwipeToKick: Bool
    let onToggleSelection: () -> Void
    let onKick: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped = false

    var body: some View {
        ZStack(alignment: .trailing) {
            if canSwipeToKick {
                Button(action: onKick) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash").font(.system(size: 16, weight: .semibold))
                        Text("Kick").font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 68)
                    .frame(maxHeight: .infinity)
                    .background(Color(uiColor: .systemGray))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kick \(participant.name)")
            }

            Button {
                if isSwiped {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0; isSwiped = false }
                } else if isSelectionMode {
                    onToggleSelection()
                }
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
            .disabled(!isSelectionMode && !isSwiped)
            .offset(x: offset)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .simultaneousGesture(canSwipeToKick ? dragGesture : nil)
        }
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityRowLabel)
        .accessibilityAddTraits(isSelectionMode && !participant.isLeader ? .isButton : [])
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .local)
            .onChanged { value in
                if value.translation.width < 0 {
                    offset = max(-68, value.translation.width)
                } else if isSwiped {
                    offset = min(0, -68 + value.translation.width)
                }
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSwiped = value.translation.width < -30
                    offset = isSwiped ? -68 : 0
                }
            }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            if isSelectionMode { selectionIndicator }

            Circle().fill(Color.secondary.opacity(0.3)).frame(width: 36, height: 36)
                .overlay { Text(String(participant.name.prefix(1))).font(.subheadline.bold()) }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                Text(participant.description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if participant.isLeader {
                Image(systemName: "crown.fill").font(.system(size: 16)).accessibilityLabel("Leader")
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if !participant.isLeader {
            ZStack {
                Circle().fill(Color(uiColor: .systemGray4)).frame(width: 24, height: 24)
                if isSelected {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.primary)
                }
            }
            .accessibilityHidden(true)
        } else {
            Color.clear.frame(width: 24, height: 24).accessibilityHidden(true)
        }
    }

    private var accessibilityRowLabel: String {
        var label = "\(participant.name), \(participant.description)"
        if participant.isLeader {
            label += ", Leader"
        } else if isSelectionMode {
            label += isSelected ? ", Selected" : ", Not selected"
        }
        return label
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
                    .font(.headline)
                    .foregroundStyle(viewModel.canRemove ? .primary : .secondary)
                    .padding(.horizontal, 24)
                    .frame(height: 44)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground)
                            .opacity(viewModel.canRemove ? 1.0 : 0.6)
                    )
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canRemove)
                    .accessibilityLabel("Remove selected participants")
            }
        } else if viewModel.isCurrentUserLeader {
            Button("Start Trip", action: onStartTrip)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(Color.accentColor)
                .clipShape(.rect(cornerRadius: 14))
                .accessibilityLabel("Start Trip")
        } else {
            Text("Waiting for leader to start...")
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).frame(minHeight: 52)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
        }
    }
}

// MARK: - Previews

#Preview {
    TripRoomView(
        viewModel: TripRoomViewModel(
            participants: [
                Participant(name: "Faishal (You)", description: "Innova Hitam - B 1234 CD", isLeader: true),
                Participant(name: "Matthew", description: "Civic Putih - B 8888 XY", isLeader: false),
                Participant(name: "Farr", description: "HR-V Abu-abu - B 4321 EF", isLeader: false)
            ],
            isCurrentUserLeader: true
        )
    )
}
