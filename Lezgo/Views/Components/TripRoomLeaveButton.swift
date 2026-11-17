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
        Button(
            viewModel.isCurrentUserLeader ? "End Trip" : "Exit Trip",
            systemImage: "chevron.left",
            action: action
        )
        .labelStyle(.iconOnly)
        .font(.callout.weight(.bold))
        .lezgoGlassButton(.round)
        .disabled(viewModel.isLeaving)
    }
}
