//
//  TripMapArrivalCardView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 27/10/26.
//

import SwiftUI

/// The top of the trip map sheet once this phone's car has arrived (`specs/UserStories.md` → US-07, "Arrive"): who
/// has arrived, and for the leader the "New Destination" choice. The leader is never blocked by late cars, so the
/// choice is there while others are still on the way.
struct TripMapArrivalCardView: View {
    let card: TripMapViewModel.ArrivalCard
    let isLeader: Bool
    /// Opens the planner with the start point locked to this destination (#115). `nil` hides the button.
    let onNewDestination: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Title())
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = Subtitle() {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(Color(.tripCardSubtext))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if isLeader, let onNewDestination {
                Button(action: onNewDestination) {
                    Text(.tripMapNewDestination)
                }
                // Yellow once everyone is there. Before that it still works, because the leader is never blocked by
                // late cars (US-07), but it is not what the leader is expected to do yet.
                .buttonStyle(TripMapCardButtonStyle(isProminent: card == .everyoneArrived))
            }
        }
    }

    private func Title() -> LocalizedStringResource {
        switch card {
        case .waitingForEveryone: .tripMapYouHaveArrived
        case .everyoneArrived: .tripMapEveryoneHasArrived
        }
    }

    private func Subtitle() -> LocalizedStringResource? {
        switch card {
        case .waitingForEveryone: .tripMapWaitingForEveryone
        case .everyoneArrived: isLeader ? .tripMapContinueYourTrip : nil
        }
    }
}

#Preview("Member, waiting") {
    TripMapArrivalCardView(card: .waitingForEveryone, isLeader: false, onNewDestination: nil)
        .padding()
        .background(Color(.tripCard))
}

#Preview("Member, everyone arrived") {
    TripMapArrivalCardView(card: .everyoneArrived, isLeader: false, onNewDestination: nil)
        .padding()
        .background(Color(.tripCard))
}

#Preview("Leader, waiting") {
    TripMapArrivalCardView(card: .waitingForEveryone, isLeader: true, onNewDestination: {})
        .padding()
        .background(Color(.tripCard))
}

#Preview("Leader, everyone arrived, largest text") {
    TripMapArrivalCardView(card: .everyoneArrived, isLeader: true, onNewDestination: {})
        .padding()
        .background(Color(.tripCard))
        .dynamicTypeSize(.accessibility5)
}
