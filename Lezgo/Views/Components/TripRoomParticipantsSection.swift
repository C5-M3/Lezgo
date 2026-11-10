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
/// Holding an avatar reports it through `onHold`, and the screen lifts it to the middle with a menu (US-04, "Manage
/// participants"): the leader can hand over the lead, edit or remove a member, anyone can edit their own details.
/// Tapping does nothing.
struct TripRoomParticipantsSection: View {
    let viewModel: TripRoomViewModel
    var isTransitioning: Bool = false
    let onHold: (Participant) -> Void
    let onInvite: () -> Void
    /// The participant whose avatar is lifted to the middle: its avatar leaves a gap here while it floats.
    var heldParticipantID: UUID?
    /// Joins this avatar to the one in `HeldAvatarOverlay`, so the avatar flies between the two.
    let avatarNamespace: Namespace.ID
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
            // The avatars are pulled up with negative padding, so their touch area reaches this row. Keep Add on top.
            .zIndex(1)
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
                            isHeld: participant.id == heldParticipantID,
                            avatarNamespace: avatarNamespace,
                            onHold: { onHold(participant) }
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
    let isHeld: Bool
    let avatarNamespace: Namespace.ID
    let onHold: () -> Void

    private var isLeader: Bool { viewModel.IsLeader(participant: participant) }
    private var isReady: Bool { viewModel.IsParticipantReady(participant) }
    private var actions: [TripRoomViewModel.ParticipantAction] { viewModel.ManagementActions(for: participant) }
    private var displayName: String { viewModel.DisplayName(of: participant) }

    var body: some View {
        if actions.isEmpty {
            card
        } else {
            card
                .onLongPressGesture(minimumDuration: 0.4, perform: onHold)
                .accessibilityAction(named: Text("Show actions"), onHold)
        }
    }

    private var card: some View {
        VStack(spacing: 4) {
            AvatarImage(avatar: participant.avatar, isSelected: isReady)
                .frame(width: AvatarImage.roomSize, height: AvatarImage.roomSize)
                .matchedGeometryEffect(id: participant.id, in: avatarNamespace)
                .opacity(isHeld ? 0 : 1)
                // The avatar is wider than its column and may spill over; the cell itself keeps the column's width,
                // so a long name is cut inside the column instead of running off the screen.
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding(.bottom, -20)
            HStack(spacing: 4) {
                // One line, cut with "…" like the hi-fi; VoiceOver still reads the whole name from the label below.
                Text(displayName)
                    .font(.headline)
                    .lineLimit(1)
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

#if DEBUG
#Preview("Leader") {
    @Previewable @Namespace var avatarNamespace
    ScrollView {
        TripRoomParticipantsSection(
            viewModel: TripRoomViewModel(
                tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.agusID),
                tripID: SampleTrip.tripID,
                myParticipantID: SampleTrip.agusID,
                initialState: SampleTrip.State(status: .lobby)
            ),
            onHold: { _ in },
            onInvite: {},
            avatarNamespace: avatarNamespace
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty, Accessibility XXXL") {
    @Previewable @Namespace var avatarNamespace
    TripRoomParticipantsSection(
        viewModel: TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.agusID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID
        ),
        onHold: { _ in },
        onInvite: {},
        avatarNamespace: avatarNamespace
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
#endif
