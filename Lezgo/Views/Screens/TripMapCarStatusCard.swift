//
//  TripMapCarStatusCard.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import SwiftUI

/// The top of the trip map sheet when a car is tapped: the driver, "Driving at [street]" (or "Stopped at", or
/// "Last seen 3 min ago") and the time left, like a place card in Apple Maps. Close (ⓧ) goes back to the trip.
struct TripMapCarStatusCard: View {
    let status: TripMapCarStatus
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: status.displayName)
                    .font(.title3.bold())
                Text(verbatim: status.statusLine)
                    .font(.subheadline)
                if let timeLeft = status.timeLeft {
                    Text(timeLeft.formatted(TripMapCarStatus.durationStyle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(.tripMapCloseCarStatus, systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, onClose)
    }
}

#Preview("Driving, with time left") {
    TripMapCarStatusCard(
        status: TripMapCarStatus(
            id: UUID(),
            displayName: "Budi",
            activity: .driving(street: "Ahmad Yani Street"),
            timeLeft: .seconds(3_000)
        ),
        onClose: {}
    )
    .padding()
}

#Preview("Stopped, before the lookup") {
    TripMapCarStatusCard(
        status: TripMapCarStatus(id: UUID(), displayName: "Citra", activity: .stopped(street: nil)),
        onClose: {}
    )
    .padding()
}

#Preview("Offline") {
    TripMapCarStatusCard(
        status: TripMapCarStatus(id: UUID(), displayName: "Dewi", activity: .offline(lastSeen: .seconds(180))),
        onClose: {}
    )
    .padding()
}

#Preview("Long names, largest text") {
    TripMapCarStatusCard(
        status: TripMapCarStatus(
            id: UUID(),
            displayName: "Bartholomew Alexander Wicaksono",
            activity: .driving(street: "Jalan Raya Prapen Indah Blok A No. 12, Tenggilis Mejoyo, Surabaya"),
            timeLeft: .seconds(4_500)
        ),
        onClose: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}
