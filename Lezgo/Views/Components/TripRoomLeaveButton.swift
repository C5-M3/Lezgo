//
//  TripRoomLeaveButton.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

/// "End Trip" for the leader, "Exit Trip" for a member, at the top left of the Trip Room (US-07, "Leave and end"). It
/// looks like a Back button, the round dark one of the route planner, but it asks to end or exit the trip, so it is
/// named for that and not "Back".
struct TripRoomLeaveButton: View {
    let viewModel: TripRoomViewModel
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "chevron.left")
                .font(.callout.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(white: 0.16).opacity(0.92)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // The arrow sits in a circle of a fixed size, so it stops growing before it would not fit.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .disabled(viewModel.isLeaving)
        .accessibilityLabel(viewModel.isCurrentUserLeader ? "End Trip" : "Exit Trip")
    }
}
