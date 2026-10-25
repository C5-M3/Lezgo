import SwiftUI

@MainActor
public struct TripRoomView: View {
    @State private var viewModel: TripRoomViewModel
    @State private var showingInviteSheet = false
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
                            viewModel.LeaveRoom()
                            dismiss()
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

                                RouteCardView(
                                    origin: viewModel.originName,
                                    destination: viewModel.destinationName
                                )
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
                                            .padding(8)
                                            .background(Color(uiColor: .secondarySystemBackground))
                                            .clipShape(.rect(cornerRadius: 8))
                                    }
                                    .frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("Invite participant")
                                }

                                ParticipantsCardView(participants: viewModel.participants)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer()

                    // Bottom Action Area
                    BottomActionView(
                        isLeader: viewModel.isCurrentUserLeader,
                        onStartTrip: viewModel.StartTrip
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showingInviteSheet) {
                InvitePlaceholderSheet()
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
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }
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
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Room options")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct RouteCardView: View {
    let origin: String
    let destination: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 12, height: 12)

                Text(origin)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)

            Divider()
                .padding(.leading, 40)

            HStack(spacing: 12) {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 12, height: 12)

                Text(destination)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}

private struct ParticipantsCardView: View {
    let participants: [Participant]

    var body: some View {
        VStack(spacing: 0) {
            if participants.isEmpty {
                Text("No participants yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                    ParticipantRowView(participant: participant)

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

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(participant.name.prefix(1)))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }

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
                    .frame(height: 52)
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
                Spacer()
            }
            .frame(height: 52)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
    }
}

private struct InvitePlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Invite Members")
                    .font(.title2.bold())
                Text("Room Code: 839201")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
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
                Participant(name: "Val", description: "HR-V Abu-abu - B 4321 EF", isLeader: false)
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
                Participant(name: "Faishal (You)", description: "Innova Hitam - B 1234 CD", isLeader: false)
            ],
            isCurrentUserLeader: false
        )
    )
}
