//
//  SetLeaderSheetView.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

struct SetLeaderSheetView: View {
    let viewModel: TripRoomViewModel
    let onSelectLeader: (Participant) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var candidate: Participant?

    var body: some View {
        NavigationStack {
            List(viewModel.participants) { participant in
                let isLeader = viewModel.IsLeader(participant: participant)
                Button {
                    guard !isLeader else { return }
                    candidate = participant
                } label: {
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
                .buttonStyle(.plain)
                .disabled(isLeader)
                .opacity(isLeader ? 0.5 : 1.0)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(participant.displayName), \(participant.carDescription), \(isLeader ? "Leader" : "Select")"
                )
                .accessibilityAddTraits(isLeader ? [] : .isButton)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pick Your New Leader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                candidate.map(viewModel.SetLeaderConfirmationTitle) ?? "",
                isPresented: Binding(
                    get: { candidate != nil },
                    set: { if !$0 { candidate = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { candidate = nil }
                Button("Confirm") {
                    if let chosen = candidate { onSelectLeader(chosen) }
                    dismiss()
                }
            }
        }
    }
}
