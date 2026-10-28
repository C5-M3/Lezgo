//
//  TripMapAlertBanner.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import SwiftUI

/// The silent formation alert under the turn card: white text on a dark red bar with a warning icon, so it reads
/// at a glance in sunlight and without colour. No sound and no vibration (`specs/UserStories.md` → US-06).
/// ⓧ hides it until the alert happens again.
struct TripMapAlertBanner: View {
    let banner: TripMapAlerts.Banner
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .accessibilityHidden(true)
            Text(Message())
                .font(.title3.bold())
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(.tripMapCloseAlert, systemImage: "xmark.circle.fill", action: onClose)
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .foregroundStyle(.white)
        .padding(.leading)
        .padding(.vertical, 8)
        .padding(.trailing, 8)
        .background(Color(.formationAlertBackground), in: .rect(cornerRadius: 20))
        // Already large and bold; any bigger, the banner and the turn card no longer fit above the map with the
        // bottom card. VoiceOver still reads the whole message.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .combine)
    }

    private func Message() -> LocalizedStringResource {
        switch banner {
        case .mine(.offRoute): .tripMapAlertOffRoute
        case .mine(.passedCheckpoint): .tripMapAlertPassedCheckpoint
        case .mine: .tripMapAlertAheadOfLeader
        case let .otherCar(_, name, .offRoute): .tripMapAlertCarOffRoute(name)
        case let .otherCar(_, name, _): .tripMapAlertCarAheadOfLeader(name)
        }
    }
}

#Preview("Every banner") {
    VStack {
        TripMapAlertBanner(banner: .mine(.offRoute), onClose: {})
        TripMapAlertBanner(banner: .mine(.passedCheckpoint), onClose: {})
        TripMapAlertBanner(banner: .mine(.aheadOfLeader), onClose: {})
        TripMapAlertBanner(banner: .otherCar(id: UUID(), name: "Budi", alert: .offRoute), onClose: {})
        TripMapAlertBanner(banner: .otherCar(id: UUID(), name: "Budi", alert: .aheadOfLeader), onClose: {})
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
