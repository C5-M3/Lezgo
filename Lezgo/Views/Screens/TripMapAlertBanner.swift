//
//  TripMapAlertBanner.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import SwiftUI

/// The silent alert under the turn card, red for a car that has stopped. No sound and no vibration
/// (`specs/UserStories.md` → US-06). A tap hides it until the alert happens again.
struct TripMapAlertBanner: View {
    let banner: TripMapAlerts.Banner
    let onClose: () -> Void

    var body: some View {
        TripMapPill(message: Text(Message()), isUrgent: IsStopped(), onTap: onClose)
    }

    private func IsStopped() -> Bool {
        if case .carStopped = banner { return true }
        return false
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
