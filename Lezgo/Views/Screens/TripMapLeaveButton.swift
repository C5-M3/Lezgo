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
        // The role tells VoiceOver this leaves the trip; the red is the same as the confirmation's red button.
        Button(role: .destructive, action: action) {
            Text(isLeader ? .tripMapEndTrip : .tripMapExitTrip)
                .foregroundStyle(Color(.tripAlertRed))
        }
        .buttonStyle(TripMapCardButtonStyle())
    }
}

#Preview("Leader and member") {
    VStack {
        TripMapLeaveButton(isLeader: true, action: {})
        TripMapLeaveButton(isLeader: false, action: {})
    }
    .padding()
    .background(Color(.tripCard))
    .environment(\.colorScheme, .dark)
}

#Preview("Largest text") {
    TripMapLeaveButton(isLeader: false, action: {})
        .padding()
        .dynamicTypeSize(.accessibility5)
}
