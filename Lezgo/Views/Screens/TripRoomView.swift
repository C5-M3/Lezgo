import SwiftUI

@MainActor
public struct TripRoomView: View {
    @State private var viewModel: TripRoomViewModel
    @State private var showingInviteSheet = false
    @State private var showingLeaveConfirmation = false
    @State private var showingStartTripConfirmation = false
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
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Top Bar
                    TopBarView(
                        onLeave: {
                            showingLeaveConfirmation = true
                        },
                        onSelect: viewModel.ToggleSelectionMode,
                        onSetLeader: {
                            if let firstMember = viewModel.participants.first(where: { !$0.isLeader }) {
                                viewModel.SetLeader(to: firstMember)
                            }
                        }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Route Trip Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Route Trip")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                RouteCardView(stops: viewModel.routeStops)
                            }

                            // Participants Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Participants")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Button {
                                        showingInviteSheet = true
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.primary)
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
                                    isSelectionMode: viewModel.isSelectionMode
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Bottom Action Area
                    BottomActionView(
                        isLeader: viewModel.isCurrentUserLeader,
                        onStartTrip: {
                            showingStartTripConfirmation = true
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarBackButtonHidden(true)
            .confirmationDialog(
                "Leave Trip Room?",
                isPresented: $showingLeaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Leave Trip Room", role: .destructive) {
                    viewModel.LeaveRoom()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Leaving without handing over the lead will end the trip for everyone.")
            }
            .alert(
                "Start trip?",
                isPresented: $showingStartTripConfirmation
            ) {
                Button("Cancel", role: .cancel) { }
                Button("Start") {
                    viewModel.StartTrip()
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                InviteSheetView(
                    roomCode: viewModel.roomCode,
                    inviteURL: viewModel.inviteURL
                )
            }
        }
    }
}

// MARK: - Local Subviews (Kept local per AGENTS.md single-use rule)

private struct TopBarView: View {
    let onLeave: () -> Void
    let onSelect: () -> Void
    let onSetLeader: () -> Void

    var body: some View {
        HStack {
            Button(action: onLeave) {
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Leave trip room")

            Spacer()

            Menu {
                Button("Select", action: onSelect)
                Button("Set leader", action: onSetLeader)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Room options")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct RouteCardView: View {
    let stops: [TripRoomViewModel.RouteStop]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: 12) {
                    Group {
                        switch stop.kind {
                        case .start:
                            Image(systemName: "house.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                        case .checkpoint:
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        case .destination:
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)

                    Text(stop.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(AccessibilityPrefix(for: stop.kind)): \(stop.name)")

                if index < stops.count - 1 {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func AccessibilityPrefix(for kind: TripRoomViewModel.RouteStopKind) -> String {
        switch kind {
        case .start:
            return "Starting point"
        case .checkpoint:
            return "Checkpoint"
        case .destination:
            return "Destination"
        }
    }
}

private struct ParticipantsCardView: View {
    let participants: [Participant]
    let isSelectionMode: Bool

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
                        isSelectionMode: isSelectionMode
                    )

                    if index < participants.count - 1 {
                        Divider()
                            .padding(.leading, 56)
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

    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(participant.name.prefix(1)))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(participant.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .accessibilityElement(children: .combine)
    }
}

private struct BottomActionView: View {
    let isLeader: Bool
    let onStartTrip: () -> Void

    var body: some View {
        if isLeader {
            Button(action: onStartTrip) {
                Text("Start Trip")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .accessibilityLabel("Start Trip")
        } else {
            HStack {
                Spacer()
                Text("Waiting for leader to start...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
    }
}

// MARK: - Previews

#Preview("Leader with Participants") {
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

#Preview("Member Waiting") {
    TripRoomView(
        viewModel: TripRoomViewModel(
            participants: [
                Participant(name: "Matthew", description: "Civic Putih - B 8888 XY", isLeader: true),
                Participant(name: "Faishal (You)", description: "Innova Hitam - B 1234 CD", isLeader: false),
                Participant(name: "Farr", description: "HR-V Abu-abu - B 4321 EF", isLeader: false)
            ],
            isCurrentUserLeader: false
        )
    )
}
