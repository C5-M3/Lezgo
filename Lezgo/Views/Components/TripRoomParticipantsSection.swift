//
//  TripRoomParticipantsSection.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

struct TripRoomParticipantsSection: View {
    let viewModel: TripRoomViewModel
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
                    let isLeader = viewModel.IsLeader(participant: participant)

                    ParticipantRowView(
                        participant: participant,
                        viewModel: viewModel,
                        onEdit: { onEdit(participant) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if viewModel.showsKickSwipe {
                            Button(role: .destructive) {
                                onKick(participant)
                            } label: {
                                Label("Kick", systemImage: "trash")
                            }
                            .disabled(!viewModel.CanKick(participant: participant))
                            .accessibilityLabel("Kick")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if viewModel.isCurrentUserLeader && !viewModel.isSelectionMode && !isLeader {
                            Button {
                                onSetLeader(participant)
                            } label: {
                                Label("Set Lead", systemImage: "crown.fill")
                            }
                            .tint(Color(uiColor: .systemGray))
                            .accessibilityLabel("Set Lead")
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

private struct ParticipantRowContent: View {
    let participant: Participant
    let isLeader: Bool
    let isReady: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(isLeader ? 0.15 : 0.3))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(participant.displayName.prefix(1))).font(.subheadline.bold())
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.displayName).font(.body.weight(.medium))
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
                ParticipantRowContent(participant: participant, isLeader: isLeader, isReady: isReady)
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
        return "\(participant.displayName), \(participant.carDescription)\(role)\(ready)\(selection)"
    }
}
