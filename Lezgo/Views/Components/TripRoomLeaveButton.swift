//
//  TripRoomLeaveButton.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

/// "End Trip" for the leader, "Exit Trip" for a member, under the participants (US-07, "Leave and end").
struct TripRoomLeaveButton: View {
    let viewModel: TripRoomViewModel
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(viewModel.isCurrentUserLeader ? "End Trip" : "Exit Trip")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.red)
        }
        .buttonStyle(.bordered)
        .tint(.gray)
        .disabled(viewModel.isLeaving)
    }
}
