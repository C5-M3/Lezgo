//
//  TripRoomStartAction.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

/// "Start Trip" for the leader, "Waiting for others ..." for a member, and "Starting Trip..." once it starts.
struct TripRoomStartAction: View {
    let viewModel: TripRoomViewModel
    let isTransitioning: Bool
    let onStartTrip: () -> Void

    var body: some View {
        if isTransitioning {
            HStack(spacing: 12) {
                ProgressView()
                Text("Starting Trip...")
            }
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
        } else if viewModel.isCurrentUserLeader {
            VStack(spacing: 6) {
                Button("Start Trip", action: onStartTrip)
                    .buttonStyle(.yellowCapsule)
                    .disabled(!viewModel.canStartTrip)
                if !viewModel.canStartTrip {
                    Text("Invite at least one friend to start.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Waiting for others ...")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        }
    }
}
