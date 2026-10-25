import SwiftUI

@MainActor
public struct TripRoomView: View {
    @State private var viewModel: TripRoomViewModel
    @State private var showingInviteSheet = false
    @State private var showingLeaveConfirmation = false
    @State private var showingStartTripConfirmation = false
    @State private var showingRemoveConfirmation = false
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
                        isSelectionMode: viewModel.isSelectionMode,
                        selectAllTitle: viewModel.selectAllButtonTitle,
                        onLeave: { showingLeaveConfirmation = true },
                        onSelect: viewModel.ToggleSelectionMode,
                        onSelectAll: viewModel.SelectAll,
                        onDoneSelection: viewModel.ToggleSelectionMode,
                        onSetLeader: {
                            if let member = viewModel.participants.first(where: { !$0.isLeader }) {
                                viewModel.SetLeader(to: member)
                            }
                        }
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
                                            .clipShape(.rect(cornerRadius: 8))
                                            .accessibilityHidden(true)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("Invite participant")
                                }

                                ParticipantsCardView(
                                    participants: viewModel.participants,
                                    isSelectionMode: viewModel.isSelectionMode,
                                    selectedParticipantIds: viewModel.selectedParticipantIds,
                                    onToggleSelection: viewModel.ToggleParticipantSelection(id:)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    BottomActionView(
                        isSelectionMode: viewModel.isSelectionMode,
                        isLeader: viewModel.isCurrentUserLeader,
                        canRemove: viewModel.canRemove,
                        onStartTrip: { showingStartTripConfirmation = true },
                        onRemove: { showingRemoveConfirmation = true }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarBackButtonHidden(true)
            .confirmationDialog("Leave Trip Room?", isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
                Button("Leave Trip Room", role: .destructive) {
                    viewModel.LeaveRoom()
                    dismiss()
                }
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
                Button("Remove", role: .destructive) {
                    viewModel.RemoveSelectedParticipants()
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                InviteSheetView(roomCode: viewModel.roomCode, inviteURL: viewModel.inviteURL)
            }
        }
    }
}

// MARK: - Local Subviews

private struct TopBarView: View {
    let isSelectionMode: Bool
    let selectAllTitle: String
    let onLeave: () -> Void
    let onSelect: () -> Void
    let onSelectAll: () -> Void
    let onDoneSelection: () -> Void
    let onSetLeader: () -> Void

    var body: some View {
        HStack {
            if isSelectionMode {
                Button(selectAllTitle, action: onSelectAll)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
            } else {
                Button(action: onLeave) {
                    Image(systemName: "door.left.hand.open").modifier(TopBarCircleIconStyle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Leave trip room")
            }

            Spacer()

            if isSelectionMode {
                Button(action: onDoneSelection) {
                    Image(systemName: "checkmark").modifier(TopBarCircleIconStyle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done selecting")
            } else {
                Menu {
                    Button("Select", action: onSelect)
                    Button("Set leader", action: onSetLeader)
                } label: {
                    Image(systemName: "ellipsis").modifier(TopBarCircleIconStyle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Room options")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct TopBarCircleIconStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .semibold))
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
                    StopIcon(for: stop.kind).frame(width: 20, height: 20)

                    Text(stop.name)
                        .font(.body)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stop.kind.accessibilityPrefix): \(stop.name)")

                if index < stops.count - 1 {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    @ViewBuilder
    private func StopIcon(for kind: TripRoomViewModel.RouteStopKind) -> some View {
        switch kind {
        case .start:
            Image(systemName: "house.fill")
                .font(.system(size: 15, weight: .semibold))
                .accessibilityHidden(true)
        case .checkpoint:
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        case .destination:
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 16, weight: .semibold))
                .accessibilityHidden(true)
        }
    }
}

private struct ParticipantsCardView: View {
    let participants: [Participant]
    let isSelectionMode: Bool
    let selectedParticipantIds: Set<UUID>
    let onToggleSelection: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if participants.isEmpty {
                Text("No participants yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                    ParticipantRowView(
                        participant: participant,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedParticipantIds.contains(participant.id),
                        onToggleSelection: { onToggleSelection(participant.id) }
                    )

                    if index < participants.count - 1 {
                        Divider().padding(.leading, isSelectionMode ? 92 : 56)
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
    let onToggleSelection: () -> Void

    var body: some View {
        Button(action: onToggleSelection) {
            HStack(spacing: 12) {
                if isSelectionMode { selectionIndicator }

                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(String(participant.name.prefix(1))).font(.subheadline.bold())
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Text(participant.description).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                if participant.isLeader {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Leader")
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isSelectionMode || participant.isLeader)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityRowLabel)
        .accessibilityAddTraits(isSelectionMode && !participant.isLeader ? .isButton : [])
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
    let isSelectionMode: Bool
    let isLeader: Bool
    let canRemove: Bool
    let onStartTrip: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if isSelectionMode {
            HStack {
                Spacer()
                Button("Remove", action: onRemove)
                    .font(.headline)
                    .foregroundStyle(canRemove ? .primary : .secondary)
                    .padding(.horizontal, 24)
                    .frame(height: 44)
                    .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(canRemove ? 1.0 : 0.6))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .disabled(!canRemove)
                    .accessibilityLabel("Remove selected participants")
            }
        } else if isLeader {
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
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
