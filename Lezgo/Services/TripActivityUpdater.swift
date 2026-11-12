//
//  TripActivityUpdater.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// Keeps the trip's Live Activity in step with the trip map open on the phone (ADR 0027).
///
/// Like CarPlay, it owns no trip: it reads the map in `ActiveTripMap` once a second. The activity starts when a map
/// opens and ends when it closes. Changes go out at most every 2 seconds, so ActivityKit does not throttle the app,
/// except an alert, an arrival or a mute tap, which the driver should see at once.
final class TripActivityUpdater {
    static let minimumInterval: TimeInterval = 2

    /// The trip map's activity at one moment.
    struct Snapshot {
        /// Which trip map it comes from, so a new map gets a new activity.
        var tripMapID: ObjectIdentifier
        var attributes: TripActivityAttributes
        var state: TripActivityAttributes.ContentState
    }

    private let activity: any TripLiveActivity
    private let clock: () -> Date
    private var hasEndedLeftovers = false
    /// The trip map whose activity is shown, or that iOS refused one for.
    private var shownFor: ObjectIdentifier?
    private var isShowing = false
    private var sentState: TripActivityAttributes.ContentState?
    private var sentAt: Date?

    init(activity: any TripLiveActivity, clock: @escaping () -> Date = { .now }) {
        self.activity = activity
        self.clock = clock
    }

    /// Follows `activeTripMap` until the app ends.
    func Run(following activeTripMap: ActiveTripMap) async {
        while Task.isCancelled == false {
            Apply(activeTripMap.tripMap?.activitySnapshot)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Starts, updates or ends the activity for what the trip map shows now; `nil` while no trip map is open.
    func Apply(_ snapshot: Snapshot?) {
        if hasEndedLeftovers == false {
            hasEndedLeftovers = true
            activity.EndLeftovers()
        }
        guard let snapshot else {
            EndShown()
            return
        }
        guard snapshot.tripMapID == shownFor else {
            EndShown()
            Start(snapshot)
            return
        }
        guard isShowing, snapshot.state != sentState else { return }
        let sinceSent = clock().timeIntervalSince(sentAt ?? .distantPast)
        guard IsUrgent(snapshot.state) || sinceSent >= Self.minimumInterval else { return }
        Send(snapshot.state)
    }

    private func Start(_ snapshot: Snapshot) {
        shownFor = snapshot.tripMapID
        isShowing = activity.Start(snapshot.attributes, state: snapshot.state)
        sentState = snapshot.state
        sentAt = clock()
    }

    private func Send(_ state: TripActivityAttributes.ContentState) {
        activity.Update(state)
        sentState = state
        sentAt = clock()
    }

    private func EndShown() {
        if isShowing { activity.End() }
        shownFor = nil
        isShowing = false
        sentState = nil
        sentAt = nil
    }

    /// A new alert, an arrival or a mute tap goes out at once.
    private func IsUrgent(_ state: TripActivityAttributes.ContentState) -> Bool {
        guard let sentState else { return true }
        return (state.alert != nil && state.alert != sentState.alert)
            || state.stage != sentState.stage
            || state.isMuted != sentState.isMuted
    }
}
