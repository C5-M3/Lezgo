//
//  TripMapNoticeBanner.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import SwiftUI

/// A notice about the route or an offline leader, in the same pill as the alerts. What has just happened hides by
/// itself after 5 seconds.
struct TripMapNoticeBanner: View {
    let notice: TripMapNotice
    /// The new time on a new route ("52 min"); `nil` until guidance knows it.
    let timeLeft: Duration?
    let onClose: () -> Void

    var body: some View {
        TripMapPill(
            message: Message(),
            isUrgent: IsUrgent(),
            onTap: notice == .rerouteFailed ? nil : onClose
        )
        .task(id: notice) {
            guard let seconds = notice.secondsOnScreen else { return }
            guard (try? await Task.sleep(for: .seconds(seconds))) != nil else { return }
            onClose()
        }
    }

    private func IsUrgent() -> Bool {
        switch notice {
        case .rerouteFailed, .leaderOffline: true
        case .newRoute, .routeUpdated: false
        }
    }

    private func Message() -> Text {
        switch notice {
        case let .newRoute(leaderName?): WithTime(.tripMapNoticeNewRouteFollowing(leaderName))
        case .newRoute(nil): WithTime(.tripMapNoticeNewRoute)
        case let .routeUpdated(leaderName?): WithTime(.tripMapNoticeRouteUpdatedBy(leaderName))
        case .routeUpdated(nil): WithTime(.tripMapNoticeRouteUpdated)
        case .rerouteFailed: Text(.tripMapNoticeRerouteFailed)
        case let .leaderOffline(name): Text(.tripMapNoticeLeaderOffline(name))
        }
    }

    /// "New route · Following Agus · 52 min"
    private func WithTime(_ message: LocalizedStringResource) -> Text {
        guard let timeLeft else { return Text(message) }
        return Text(verbatim: "\(String(localized: message)) · \(timeLeft.formatted(TripMapCarStatus.durationStyle))")
    }
}

#Preview("Every notice") {
    VStack(spacing: 12) {
        ForEach(
            [
                TripMapNotice.newRoute(leaderName: "Agus"),
                .routeUpdated(leaderName: "Agus"),
                .rerouteFailed,
                .leaderOffline(name: "Agus")
            ],
            id: \.self
        ) { notice in
            TripMapNoticeBanner(notice: notice, timeLeft: .seconds(3_120), onClose: {})
        }
    }
    .padding(12)
}
