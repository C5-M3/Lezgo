//
//  TripMapCarStatusCard.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import SwiftUI

/// The card that opens when a car is tapped on the trip map: the driver, "Driving at [street]" (or "Stopped at",
/// or "Last seen 3 min ago") and the time left. Swipe down to close.
struct TripMapCarStatusCard: View {
    let status: TripMapCarStatus
    let onClose: () -> Void

    /// How far the card must be dragged down to close.
    private static let closeDragDistance: CGFloat = 40

    var body: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(.secondary)
                .frame(width: 36, height: 5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: status.displayName)
                    .font(.headline)
                Text(verbatim: status.statusLine)
                    .font(.subheadline)
                if let timeLeft = status.timeLeft {
                    // Primary, not secondary: grey text on glass over a bright map falls below 4.5:1 contrast.
                    Text(timeLeft.formatted(TripMapCarStatus.durationStyle))
                        .font(.subheadline)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: Text(.tripMapCloseCarStatus), onClose)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 24))
        .contentShape(.rect(cornerRadius: 24))
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { drag in
                if drag.translation.height > Self.closeDragDistance { onClose() }
            }
        )
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
