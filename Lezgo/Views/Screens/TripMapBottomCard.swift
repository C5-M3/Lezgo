//
//  TripMapBottomCard.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The bottom card on the trip map: "To [destination]", the time left, and "End Trip" or "Exit Trip".
struct TripMapBottomCard: View {
    let destinationName: String
    /// `nil` until the first guidance arrives; the card then shows only the destination.
    let timeLeft: Duration?
    let isLeader: Bool
    let onLeave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(.tripMapToDestination(destinationName))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let timeLeft {
                    Text(timeLeft.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                        // Primary, not secondary: grey text on glass over a bright map falls below 4.5:1 contrast.
                        .font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)

            TripMapLeaveButton(isLeader: isLeader, action: onLeave)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

#Preview("With time left") {
    TripMapBottomCard(
        destinationName: "Ciputra World Surabaya",
        timeLeft: .seconds(3_000),
        isLeader: true,
        onLeave: {}
    )
        .padding()
}

#Preview("Before guidance, long name, largest text") {
    TripMapBottomCard(
        destinationName: "Pakuwon Mall, Jalan Puncak Indah Lontar No. 2, Babatan, Wiyung, Surabaya",
        timeLeft: nil,
        isLeader: false,
        onLeave: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}
