//
//  TripRoomParticipantsSection.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

struct TripRoomParticipantsSection: View {
    let viewModel: TripRoomViewModel
    var isTransitioning: Bool = false
    let onKick: (Participant) -> Void
    let onSetLeader: (Participant) -> Void
    let onEdit: (Participant) -> Void
    let onInvite: () -> Void

    var body: some View {
        Section {
            if viewModel.participants.isEmpty {
                Text("No participants yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(viewModel.participants) { participant in
                    ParticipantRowView(
                        participant: participant,
                        viewModel: viewModel,
                        onEdit: { onEdit(participant) }
                    )
                    .disabled(isTransitioning)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isTransitioning && viewModel.showsKickSwipe {
                            KickSwipeButton(isEnabled: viewModel.CanKick(participant: participant)) {
                                onKick(participant)
                            }
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if !isTransitioning && viewModel.showsSetLeaderSwipe {
                            SetLeadSwipeButton(isEnabled: viewModel.CanSetLeader(participant: participant)) {
                                onSetLeader(participant)
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Participants")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                Spacer()
                if !isTransitioning {
                    Button(action: onInvite) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .accessibilityHidden(true)
                            .frame(width: 32, height: 32)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Invite participant")
                }
            }
        }
    }
}

/// "Kick" in a row's swipe actions. It has no `.destructive` role: that role makes SwiftUI drop a row from the
/// list as soon as it is tapped, before the leader confirms. Swipe actions also ignore `.disabled`, so the
/// leader's own row gets a gray button that does nothing (lo-fi "SLIDE DELETE IF LEADER").
private struct KickSwipeButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Label("Kick", systemImage: "trash")
        }
        .tint(isEnabled ? Color.red : Color(uiColor: .systemGray4))
        .disabled(!isEnabled)
        .accessibilityLabel("Kick")
        // `.disabled` does not reach swipe actions, so VoiceOver would not say "dimmed".
        // The hint says why it does nothing.
        .accessibilityHint(isEnabled ? Text(verbatim: "") : Text(.tripRoomLeaderRowHint))
    }
}

/// "Set Lead" in a row's swipe actions. Swipe actions ignore `.disabled`, so the leader's own row gets a lighter
/// gray button that does nothing (lo-fi "SET LEAD IF LEADERS IS SELECTED VIA SLIDER").
private struct SetLeadSwipeButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Label("Set Lead", systemImage: "crown.fill")
        }
        .tint(Color(uiColor: isEnabled ? .systemGray : .systemGray4))
        .disabled(!isEnabled)
        .accessibilityLabel("Set Lead")
        // `.disabled` does not reach swipe actions, so VoiceOver would not say "dimmed".
        // The hint says why it does nothing.
        .accessibilityHint(isEnabled ? Text(verbatim: "") : Text(.tripRoomLeaderRowHint))
    }
}

private struct ParticipantRowContent: View {
    let participant: Participant
    /// The typed name, or "Leader", "Car 2", …
    let displayName: String
    let isLeader: Bool
    let isReady: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(isLeader ? 0.15 : 0.3))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(displayName.prefix(1))).font(.subheadline.bold())
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName).font(.body.weight(.medium))
                Text(participant.carDescription).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(isReady ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                    Text(isReady ? "ready at startpoint" : "not ready at startpoint")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            Spacer()
            if isLeader {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Leader")
            }
        }
    }
}

private struct ParticipantRowView: View {
    let participant: Participant
    let viewModel: TripRoomViewModel
    let onEdit: () -> Void

    private var isSelected: Bool { viewModel.selectedParticipantIds.contains(participant.id) }
    private var isLeader: Bool { viewModel.IsLeader(participant: participant) }
    private var isReady: Bool { viewModel.IsParticipantReady(participant) }

    var body: some View {
        Button {
            if viewModel.isSelectionMode {
                viewModel.ToggleParticipantSelection(id: participant.id)
            } else if viewModel.CanEdit(participant: participant) {
                onEdit()
            }
        } label: {
            HStack(spacing: 12) {
                if viewModel.isSelectionMode && !isLeader {
                    ZStack {
                        Circle().fill(Color(uiColor: .systemGray4))
                        if isSelected {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                }
                ParticipantRowContent(
                    participant: participant,
                    displayName: viewModel.DisplayName(of: participant),
                    isLeader: isLeader,
                    isReady: isReady
                )
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(
            (viewModel.isSelectionMode && !isLeader) || viewModel.CanEdit(participant: participant) ? .isButton : []
        )
    }

    private var accessibilityLabel: String {
        let role = isLeader ? ", Leader" : ""
        let ready = isReady ? ", ready at startpoint" : ", not ready at startpoint"
        let selection = viewModel.isSelectionMode ? (isSelected ? ", Selected" : ", Not selected") : ""
        return "\(viewModel.DisplayName(of: participant)), \(participant.carDescription)\(role)\(ready)\(selection)"
    }
}
