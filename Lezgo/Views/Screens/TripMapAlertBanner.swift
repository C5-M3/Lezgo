//
//  TripMapAlertBanner.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import SwiftUI

/// The silent alert under the turn card: a yellow pill for the way the group is driving, a red one for a car that has
/// stopped. Dark text and an icon, so it reads at a glance in sunlight and without colour. No sound and no vibration
/// (`specs/UserStories.md` → US-06). A tap hides it until the alert happens again.
struct TripMapAlertBanner: View {
    let banner: TripMapAlerts.Banner
    let onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .accessibilityHidden(true)
                Text(Message())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline.bold())
            .foregroundStyle(Color(.tripCard))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Background(), in: .rect(cornerRadius: 22))
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        // Any bigger, the banner and the turn card no longer fit above the map with the bottom card. VoiceOver still
        // reads the whole message.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityHint(Text(.tripMapCloseAlert))
    }

    private func Background() -> Color {
        if case .carStopped = banner { return Color(.tripAlertRed) }
        return Color(.brandYellow)
    }

    private func Message() -> LocalizedStringResource {
        switch banner {
        case .mine(.offRoute): .tripMapAlertOffRoute
        case .mine(.passedCheckpoint): .tripMapAlertPassedCheckpoint
        case .mine(.passedDestination): .tripMapAlertPassedDestination
        case .mine: .tripMapAlertAheadOfLeader
        case let .otherCar(_, name, .offRoute): .tripMapAlertCarOffRoute(name)
        case let .otherCar(_, name, _): .tripMapAlertCarAheadOfLeader(name)
        case let .carStopped(_, name): .tripMapAlertCarStopped(name)
        }
    }
}

#Preview("Every banner") {
    VStack {
        TripMapAlertBanner(banner: .mine(.offRoute), onClose: {})
        TripMapAlertBanner(banner: .mine(.passedCheckpoint), onClose: {})
        TripMapAlertBanner(banner: .mine(.passedDestination), onClose: {})
        TripMapAlertBanner(banner: .mine(.aheadOfLeader), onClose: {})
        TripMapAlertBanner(banner: .otherCar(id: UUID(), name: "Budi", alert: .offRoute), onClose: {})
        TripMapAlertBanner(banner: .otherCar(id: UUID(), name: "Budi", alert: .aheadOfLeader), onClose: {})
        TripMapAlertBanner(banner: .carStopped(id: UUID(), name: "Citra"), onClose: {})
    }
    .padding()
}

#Preview("Long name, largest text") {
    TripMapAlertBanner(
        banner: .otherCar(id: UUID(), name: "Bartholomew Wijayakusuma Santoso", alert: .aheadOfLeader),
        onClose: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}
