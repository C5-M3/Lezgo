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
            message: Text(verbatim: notice.Message(timeLeft: timeLeft)),
            isUrgent: notice.isUrgent,
            onTap: notice == .rerouteFailed ? nil : onClose
        )
        .task(id: notice) {
            guard let seconds = notice.secondsOnScreen else { return }
            guard (try? await Task.sleep(for: .seconds(seconds))) != nil else { return }
            onClose()
        }
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
