//
//  TripMapLeaveButton.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 27/10/26.
//

import SwiftUI

/// The red button at the bottom of the trip map: "End Trip" for the leader, "Exit Trip" for a member. Both ask for
/// confirmation first (`specs/UserStories.md` → US-07, "Leave and end").
struct TripMapLeaveButton: View {
    let isLeader: Bool
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(isLeader ? .tripMapEndTrip : .tripMapExitTrip)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

#Preview("Leader and member") {
    VStack {
        TripMapLeaveButton(isLeader: true, action: {})
        TripMapLeaveButton(isLeader: false, action: {})
    }
    .padding()
}

#Preview("Largest text") {
    TripMapLeaveButton(isLeader: false, action: {})
        .padding()
        .dynamicTypeSize(.accessibility5)
}
