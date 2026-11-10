//
//  TripMapCarStatusCard.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import SwiftUI

/// The top of the trip map's bottom card when a car is tapped: its robot, the driver and car, the time left, and what
/// the car is doing. A tap elsewhere on the map, or pulling the card down, closes it (`specs/UserStories.md` → US-06).
struct TripMapCarStatusCard: View {
    let status: TripMapCarStatus
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 32
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The mascot's body fills only part of its image; the rest is transparent margin.
    private static let mascotImageSize = 130.0

    /// As in the hi-fi ("04 Trip Started", a tapped car): the name with what the car is doing beside it, the car,
    /// then where it is and how long it has left, and the whole mascot on the right.
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) { NameAndStatus() }
                    VStack(alignment: .leading, spacing: 4) { NameAndStatus() }
                }
                if status.carDescription.isEmpty == false {
                    Text(verbatim: status.carDescription)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.tripCardText))
                }
                if HasDetail() {
                    Text(verbatim: status.statusLine)
                        .font(.callout)
                        .foregroundStyle(Color(.tripCardSubtext))
                }
                if let timeLeft = status.timeLeft {
                    Text(timeLeft.formatted(TripMapCarStatus.durationStyle))
                        .font(.system(size: timeSize, weight: .black))
                        .foregroundStyle(Color(.brandYellow))
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(status.carColor.fullBodyImage)
                .resizable()
                .scaledToFit()
                .frame(width: Self.mascotImageSize, height: Self.mascotImageSize)
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
    private func NameAndStatus() -> some View {
        Text(verbatim: status.displayName)
            .font(.title2.bold())
            .foregroundStyle(.white)
        Chip(activity: status.activity)
    }

    private func IsOffline() -> Bool {
        if case .offline = status.activity { return true }
        return false
    }

    /// The line under the chip says where the car is or when it was last seen. Without a street it would only repeat
    /// the chip.
    private func HasDetail() -> Bool {
        switch status.activity {
        case .driving(street: nil), .stopped(street: nil): false
        default: true
        }
    }
}

extension TripMapCarStatusCard {
    /// What the car is doing, by icon, text and colour.
    struct Chip: View {
        let activity: TripMapCarStatus.Activity

        var body: some View {
            // Yellow while driving, as in the hi-fi; grey once stopped or offline. The icon carries the meaning too.
            Label(Title(), systemImage: Symbol())
                .contentTransition(.symbolEffect(.replace))
                .font(.subheadline.bold())
                .foregroundStyle(IsDriving() ? Color(.brandYellow) : Color(.tripCardSubtext))
        }

        private func IsDriving() -> Bool {
            if case .driving = activity { return true }
            return false
        }

        private func Title() -> LocalizedStringResource {
            switch activity {
            case .driving: .tripMapCarDriving
            case .stopped: .tripMapCarStopped
            case .offline: .tripMapCarOffline
            }
        }

        private func Symbol() -> String {
            switch activity {
            case .driving: "car.fill"
            case .stopped: "pause.fill"
            case .offline: "wifi.slash"
            }
        }
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
