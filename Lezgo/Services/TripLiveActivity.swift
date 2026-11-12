//
//  TripLiveActivity.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import ActivityKit
import Foundation

/// Shows the trip's Live Activity (ADR 0027). `LiveTripLiveActivity` uses ActivityKit; tests use a mock.
protocol TripLiveActivity: AnyObject {
    /// Shows a new activity. `false` when iOS refused, for example because Live Activities are off for Lezgo.
    func Start(_ attributes: TripActivityAttributes, state: TripActivityAttributes.ContentState) -> Bool
    func Update(_ state: TripActivityAttributes.ContentState)
    /// Removes the activity at once: a trip that has closed must never stay on the Lock Screen.
    func End()
    /// Removes activities an earlier run of the app left behind, for example after it was quit during a trip.
    func EndLeftovers()
}

/// The real Live Activity, updated from the phone itself: there is no push server (ADR 0027).
final class LiveTripLiveActivity: TripLiveActivity {
    /// iOS greys the activity out when the app has not updated it for this long, as a car counts as offline then.
    private static let staleAfter = Participant.offlineAfter

    private var activity: Activity<TripActivityAttributes>?

    func Start(_ attributes: TripActivityAttributes, state: TripActivityAttributes.ContentState) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        do {
            activity = try Activity.request(attributes: attributes, content: Content(state), pushType: nil)
            return true
        } catch {
            return false
        }
    }

    func Update(_ state: TripActivityAttributes.ContentState) {
        guard let activity else { return }
        let content = Content(state)
        Task { await activity.update(content) }
    }

    func End() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    func EndLeftovers() {
        let leftovers = Activity<TripActivityAttributes>.activities
        Task {
            for leftover in leftovers {
                await leftover.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func Content(_ state: TripActivityAttributes.ContentState) -> ActivityContent<TripActivityAttributes.ContentState> {
        ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(Self.staleAfter))
    }
}
