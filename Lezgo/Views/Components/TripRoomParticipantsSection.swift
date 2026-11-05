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
/// Tapping an avatar opens Edit Profile when I may edit it; there the leader also finds "Kick" and "Set Lead" (US-05).
struct TripRoomParticipantsSection: View {
    let viewModel: TripRoomViewModel
    var isTransitioning: Bool = false
    let onEdit: (Participant) -> Void
    let onInvite: () -> Void
    /// Grows with Dynamic Type, so large text gets fewer, wider columns instead of cut-off names.
    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            if viewModel.participants.isEmpty {
                Text("No participants yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: 16, alignment: .top)],
                          spacing: 20) {
                    ForEach(viewModel.participants) { participant in
                        ParticipantCell(
                            participant: participant,
                            viewModel: viewModel,
                            onEdit: { onEdit(participant) }
                        )
                        .disabled(isTransitioning)
                    }
                }
            }
        }
    }
}

private struct ParticipantCell: View {
    let participant: Participant
    let viewModel: TripRoomViewModel
    let onEdit: () -> Void

    private var isLeader: Bool { viewModel.IsLeader(participant: participant) }
    private var isReady: Bool { viewModel.IsParticipantReady(participant) }
    private var canEdit: Bool { viewModel.CanEdit(participant: participant) }
    private var displayName: String { viewModel.DisplayName(of: participant) }

    var body: some View {
        Button(action: onEdit) {
            VStack(spacing: 4) {
                AvatarImage(avatar: participant.avatar, isSelected: isReady)
                    .frame(width: 160, height: 160).padding(.bottom, -20)
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
        }
        .buttonStyle(.plain)
        // A member's tap on someone else does nothing; disabling would dim the avatar, which looks like "not ready".
        .allowsHitTesting(canEdit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(canEdit ? .isButton : [])
        .accessibilityHint(canEdit ? Text("Opens Edit Profile") : Text(verbatim: ""))
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
    ScrollView {
        TripRoomParticipantsSection(
            viewModel: TripRoomViewModel(
                tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.agusID),
                tripID: SampleTrip.tripID,
                myParticipantID: SampleTrip.agusID,
                initialState: SampleTrip.State(status: .lobby)
            ),
            onEdit: { _ in },
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
        onInvite: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
#endif
