//
//  TripMapCarStatusCard.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import SwiftUI

/// The top of the trip map's bottom card when a car is tapped: its robot, the driver and car, what the car is doing,
/// and the time left to where it is heading. A tap elsewhere on the map, or pulling the card down, closes it
/// (`specs/UserStories.md` → US-06).
struct TripMapCarStatusCard: View {
    let status: TripMapCarStatus
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 32
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The mascot's body fills only part of its image; the rest is transparent margin.
    private static let mascotImageSize = 130.0
    /// The mascot is drawn larger than the room it takes, so the time and the next stop still fit on one line.
    private static let mascotScale = 1.6

    /// As in the hi-fi ("04 Trip Started", a tapped car): the name, the car, "Status: Driving" in yellow, then the time
    /// left with where the car is heading, and the whole mascot on the right.
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: status.displayName)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if status.carDescription.isEmpty == false {
                    Text(verbatim: status.carDescription)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.tripCardSubtext))
                }
                Text(verbatim: status.cardStatusLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(StatusColor())
                if let lastSeenLine = status.lastSeenLine {
                    Text(verbatim: lastSeenLine)
                        .font(.callout)
                        .foregroundStyle(Color(.tripCardSubtext))
                }
                if let timeLeft = status.timeLeft {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) { TimeAndNextStop(timeLeft) }
                        VStack(alignment: .leading, spacing: 2) { TimeAndNextStop(timeLeft) }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(status.carColor.fullBodyImage)
                .resizable()
                .scaledToFit()
                .frame(width: Self.mascotImageSize, height: Self.mascotImageSize)
                .scaleEffect(Self.mascotScale)
                .opacity(IsOffline() ? 0.4 : 1)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion), value: status)
        .accessibilityElement(children: .combine)
        .accessibilityAction(.escape, onClose)
        .accessibilityAction(named: Text(.tripMapCloseCarStatus), onClose)
    }

    @ViewBuilder
    private func TimeAndNextStop(_ timeLeft: Duration) -> some View {
        Text(timeLeft.formatted(TripMapCarStatus.durationStyle))
            .font(.system(size: timeSize, weight: .black))
            .foregroundStyle(.white)
            .contentTransition(.numericText(countsDown: true))
        if let nextStopLine = status.nextStopLine {
            Text(verbatim: nextStopLine)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    /// Yellow while driving, as in the hi-fi; red once stopped, like the "has stopped" banner; white when offline.
    /// The words say the status too, so colour is never the only sign.
    private func StatusColor() -> Color {
        switch status.activity {
        case .driving: Color(.brandYellow)
        case .stopped: Color(.tripAlertRed)
        case .offline: Color(.tripCardText)
        }
    }

    private func IsOffline() -> Bool {
        if case .offline = status.activity { return true }
        return false
    }
}

#Preview("Driving, with time left") {
    TripMapCarStatusCard(
        status: TripMapCarStatus(
            id: UUID(),
            displayName: "Budi",
            activity: .driving(street: "Ahmad Yani Street"),
            timeLeft: .seconds(3_600),
            nextStopName: "Tunjungan Plaza",
            carDescription: "Toyota Avanza Black"
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
            timeLeft: .seconds(4_500),
            nextStopName: "Jalan Raya Prapen Indah Blok A No. 12, Tenggilis Mejoyo, Surabaya"
        ),
        onClose: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}
