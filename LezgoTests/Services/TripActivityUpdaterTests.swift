//
//  TripActivityUpdaterTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// When the trip's Live Activity starts, changes and ends (ADR 0028).
@MainActor
struct TripActivityUpdaterTests {
    private final class Clock {
        var now = TripMapFixtures.now
    }

    private let activity = MockTripLiveActivity()
    private let clock = Clock()
    private let tripMap = NSObject()
    private let attributes = TripActivityAttributes(title: "To Puncak")

    private func MakeUpdater() -> TripActivityUpdater {
        let clock = clock
        return TripActivityUpdater(activity: activity, clock: { clock.now })
    }

    private func State(
        stage: TripActivityAttributes.Stage = .driving,
        title: String = "To Rest area",
        timeText: String = "50 min"
    ) -> TripActivityAttributes.ContentState {
        TripActivityAttributes.ContentState(
            stage: stage,
            title: title,
            timeText: timeText,
            shortTimeText: timeText,
            distanceText: "12 km",
            countText: nil,
            legStartLabel: "Start",
            legEndLabel: "Stop 1 of 2",
            robots: [],
            reached: 0,
            myColor: .blue
        )
    }

    private func Snapshot(
        _ state: TripActivityAttributes.ContentState,
        of tripMap: AnyObject? = nil
    ) -> TripActivityUpdater.Snapshot {
        TripActivityUpdater.Snapshot(
            tripMapID: ObjectIdentifier(tripMap ?? self.tripMap),
            attributes: attributes,
            state: state
        )
    }

    private var updates: [MockTripLiveActivity.Call] {
        activity.calls.filter { if case .update = $0 { true } else { false } }
    }

    @Test func LaunchEndsActivitiesLeftFromAnEarlierRun() {
        let updater = MakeUpdater()
        updater.Apply(nil)
        updater.Apply(nil)
        #expect(activity.calls == [.endLeftovers])
    }

    @Test func OpeningTheTripMapStartsTheActivity() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        #expect(activity.calls == [.endLeftovers, .start(title: "To Puncak", stage: .driving)])
    }

    @Test func ClosingTheTripMapEndsTheActivity() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        updater.Apply(nil)
        updater.Apply(nil)
        #expect(activity.calls.last == .end)
        #expect(activity.calls.filter { $0 == .end }.count == 1)
    }

    @Test func NothingChangedSendsNothing() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 5
        updater.Apply(Snapshot(State()))
        #expect(updates.isEmpty)
    }

    @Test func ChangeIsSent() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 3
        updater.Apply(Snapshot(State(timeText: "49 min")))
        #expect(updates == [.update(State(timeText: "49 min"))])
    }

    @Test func ChangesWithinTwoSecondsWaitForTheNextTick() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 1
        updater.Apply(Snapshot(State(timeText: "49 min")))
        #expect(updates.isEmpty)
        clock.now += 1
        updater.Apply(Snapshot(State(timeText: "49 min")))
        #expect(updates == [.update(State(timeText: "49 min"))])
    }

    @Test func NextLegIsSentAtOnce() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 0.5
        updater.Apply(Snapshot(State(title: "To Pakuwon mall")))
        #expect(updates == [.update(State(title: "To Pakuwon mall"))])
    }

    @Test func ArrivingIsSentAtOnce() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 0.5
        updater.Apply(Snapshot(State(stage: .arrived)))
        #expect(updates.count == 1)
    }

    @Test func ANewTripMapReplacesTheActivity() {
        let updater = MakeUpdater()
        let newTripMap = NSObject()
        updater.Apply(Snapshot(State()))
        updater.Apply(Snapshot(State(), of: newTripMap))
        #expect(activity.calls == [
            .endLeftovers,
            .start(title: "To Puncak", stage: .driving),
            .end,
            .start(title: "To Puncak", stage: .driving)
        ])
    }

    @Test func LiveActivitiesTurnedOffSendsNoUpdates() {
        activity.canStart = false
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 3
        updater.Apply(Snapshot(State(timeText: "48 min")))
        updater.Apply(nil)
        #expect(activity.calls == [.endLeftovers, .start(title: "To Puncak", stage: .driving)])
    }
}
