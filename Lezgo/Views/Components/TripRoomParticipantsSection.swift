//
//  TripRoomParticipantsSection.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

/// "Participants": every car's avatar, name and car, with "Add" to invite (US-04, "Room").
///
/// The avatar shows who is ready at the start point: the selected image when ready, the unselected one when not.
/// Holding an avatar lifts it to the middle of the screen with a menu (US-04, "Manage participants"): the leader can
/// hand over the lead, edit or remove a member, anyone can edit their own details. Tapping does nothing.
struct TripRoomParticipantsSection: View {
    let viewModel: TripRoomViewModel
    var isTransitioning: Bool = false
    let onEdit: (Participant) -> Void
    let onSetLeader: (Participant) -> Void
    let onRemove: (Participant) -> Void
    let onInvite: () -> Void
    /// Grows with Dynamic Type, so large text gets fewer, wider columns instead of cut-off names.
    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Participants")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !isTransitioning {
                    Button("Add", action: onInvite)
                        .font(.headline)
                        .foregroundStyle(Color(.brandYellow))
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Add participants")
                }
            }
            .padding(.bottom, -10)
            if viewModel.participants.isEmpty {
                Text("No participants yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: columnWidth), spacing: 16, alignment: .top)],
                    spacing: 0
                ) {
                    ForEach(viewModel.participants) { participant in
                        ParticipantCell(
                            participant: participant,
                            viewModel: viewModel,
                            onEdit: { onEdit(participant) },
                            onSetLeader: { onSetLeader(participant) },
                            onRemove: { onRemove(participant) }
                        )
                        .disabled(isTransitioning)
                    }
                }
                if !isTransitioning {
                    Text(viewModel.isCurrentUserLeader ? "Hold to manage participants" : "Hold to edit your profile")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }
        }
    }
}

private struct ParticipantCell: View {
    let participant: Participant
    let viewModel: TripRoomViewModel
    let onEdit: () -> Void
    let onSetLeader: () -> Void
    let onRemove: () -> Void

    private var isLeader: Bool { viewModel.IsLeader(participant: participant) }
    private var isReady: Bool { viewModel.IsParticipantReady(participant) }
    private var actions: [TripRoomViewModel.ParticipantAction] { viewModel.ManagementActions(for: participant) }
    private var displayName: String { viewModel.DisplayName(of: participant) }

    var body: some View {
        if actions.isEmpty {
            card
        } else {
            card.contextMenu {
                ForEach(actions, id: \.self) { action in
                    MenuButton(action: action, onEdit: onEdit, onSetLeader: onSetLeader, onRemove: onRemove)
                }
            } preview: {
                HeldAvatar(participant: participant, displayName: displayName, isReady: isReady)
            }
        }
    }

    private var card: some View {
        VStack(spacing: 4) {
            AvatarImage(avatar: participant.avatar, isSelected: isReady)
                .frame(width: AvatarImage.roomSize, height: AvatarImage.roomSize)
                .padding(.bottom, -20)
            HStack(spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if isLeader {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(Color(.brandYellow))
                        .accessibilityHidden(true)
                }
            }
            if !participant.carDescription.isEmpty {
                Text(participant.carDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(actions.isEmpty ? Text(verbatim: "") : Text("Opens a menu with actions"))
        .padding(.top, -15)
    }

    private var accessibilityLabel: String {
        let parts = [
            displayName,
            participant.carDescription.isEmpty ? nil : participant.carDescription,
            isLeader ? String(localized: "Leader") : nil,
            participant.avatar.accessibilityName,
            isReady ? String(localized: "Ready at start point") : String(localized: "Not ready at start point")
        ]
        return parts.compactMap(\.self).joined(separator: ", ")
    }
}

/// One entry of the menu of a held avatar.
private struct MenuButton: View {
    let action: TripRoomViewModel.ParticipantAction
    let onEdit: () -> Void
    let onSetLeader: () -> Void
    let onRemove: () -> Void

    var body: some View {
        switch action {
        case .setLeader:
            Button("Set as Trip Leader", systemImage: "crown", action: onSetLeader)
        case .editDetails:
            Button("Edit Details", systemImage: "pencil", action: onEdit)
        case .remove:
            Button("Remove from Trip", systemImage: "person.badge.minus", role: .destructive, action: onRemove)
        }
    }
}

/// What floats to the middle of the screen while the menu is open: the avatar with its name and car.
private struct HeldAvatar: View {
    let participant: Participant
    let displayName: String
    let isReady: Bool

    var body: some View {
        VStack(spacing: 8) {
            AvatarImage(avatar: participant.avatar, isSelected: true)
                .frame(width: 200, height: 200)
            Text(participant.carDescription.isEmpty ? displayName : "\(displayName) · \(participant.carDescription)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding()
    }
}

#if DEBUG
#Preview("Leader") {
    ScrollView {
        TripRoomParticipantsSection(
            viewModel: TripRoomViewModel(
                tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.agusID),
                tripID: SampleTrip.tripID,
                myParticipantID: SampleTrip.agusID,
                initialState: SampleTrip.State(status: .lobby)
            ),
            onEdit: { _ in },
            onSetLeader: { _ in },
            onRemove: { _ in },
            onInvite: {}
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty, Accessibility XXXL") {
    TripRoomParticipantsSection(
        viewModel: TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.agusID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID
        ),
        onEdit: { _ in },
        onSetLeader: { _ in },
        onRemove: { _ in },
        onInvite: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
#endif
