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
            .foregroundStyle(Color(.tripCardSubtext))
            .frame(maxWidth: .infinity, minHeight: 56)
        } else if viewModel.isCurrentUserLeader {
            VStack(spacing: 6) {
                Button("Start Trip", action: onStartTrip)
                    .lezgoGlassButton(.main)
                    .disabled(!viewModel.canStartTrip)
                if !viewModel.canStartTrip {
                    Text("Invite at least one friend to start")
                        .font(.footnote)
                        .foregroundStyle(Color(.tripCardSubtext))
                }
            }
        } else {
            Text("Waiting for others ...")
                .font(.headline)
                .foregroundStyle(Color(.tripCardSubtext))
                .frame(maxWidth: .infinity, minHeight: 56)
                .lezgoSurface(.level1, radius: LezgoRadius.card)
        }
    }
}
