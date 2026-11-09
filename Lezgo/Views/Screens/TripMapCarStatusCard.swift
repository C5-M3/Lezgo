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

    /// The robot's body fills only part of its image; the rest is transparent margin.
    private static let robotImageSize = 56 / 0.426

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(status.carColor.frontImage)
                    .resizable()
                    .frame(width: Self.robotImageSize, height: Self.robotImageSize)
                    .frame(width: 56, height: 56)
                    .opacity(IsOffline() ? 0.4 : 1)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: status.displayName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    if status.carDescription.isEmpty == false {
                        Text(verbatim: status.carDescription)
                            .font(.callout)
                            .foregroundStyle(Color(.tripCardSubtext))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let timeLeft = status.timeLeft {
                    Text(timeLeft.formatted(TripMapCarStatus.durationStyle))
                        .font(.system(size: timeSize, weight: .black))
                        .foregroundStyle(Color(.brandYellow))
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Chip(activity: status.activity)

            if HasDetail() {
                Text(verbatim: status.statusLine)
                    .font(.callout)
                    .foregroundStyle(Color(.tripCardText))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAction(.escape, onClose)
        .accessibilityAction(named: Text(.tripMapCloseCarStatus), onClose)
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
            Label(Title(), systemImage: Symbol())
                .font(.subheadline.bold())
                .foregroundStyle(IsDriving() ? Color(.tripCard) : Color(.tripCardText))
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .background(IsDriving() ? Color(.brandGreen) : Color(.tripCardButton), in: .capsule)
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
