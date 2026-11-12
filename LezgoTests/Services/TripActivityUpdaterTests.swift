//
//  TripActivityUpdaterTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// When the trip's Live Activity starts, changes and ends (ADR 0027).
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
        turnText: String = "300 m",
        alert: TripActivityAttributes.Alert? = nil,
        isMuted: Bool = false
    ) -> TripActivityAttributes.ContentState {
        TripActivityAttributes.ContentState(
            stage: stage,
            turn: TripActivityAttributes.Turn(symbolName: "arrow.up", distanceText: turnText, instruction: "Continue"),
            timeLeftText: "1 hr, 20 min",
            shortTimeLeftText: "1:20",
            detailText: nil,
            nextStopText: nil,
            groupText: "Following Budi",
            isGroupWarning: false,
            alert: alert,
            arrival: nil,
            robots: [],
            myColor: .blue,
            isLeader: false,
            isMuted: isMuted,
            muteLabel: isMuted ? "Unmute" : "Mute"
        )
    }

    private func Snapshot(_ state: TripActivityAttributes.ContentState, of tripMap: AnyObject? = nil) -> TripActivityUpdater.Snapshot {
        TripActivityUpdater.Snapshot(tripMapID: ObjectIdentifier(tripMap ?? self.tripMap), attributes: attributes, state: state)
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
        updater.Apply(Snapshot(State(turnText: "200 m")))
        #expect(updates == [.update(State(turnText: "200 m"))])
    }

    @Test func ChangesWithinTwoSecondsWaitForTheNextTick() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 1
        updater.Apply(Snapshot(State(turnText: "250 m")))
        #expect(updates.isEmpty)
        clock.now += 1
        updater.Apply(Snapshot(State(turnText: "250 m")))
        #expect(updates == [.update(State(turnText: "250 m"))])
    }

    @Test func NewAlertIsSentAtOnce() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 0.5
        let alert = TripActivityAttributes.Alert(text: "Citra has gone out of route", color: .pink, carName: "Citra")
        updater.Apply(Snapshot(State(alert: alert)))
        #expect(updates == [.update(State(alert: alert))])
    }

    @Test func ArrivingIsSentAtOnce() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 0.5
        updater.Apply(Snapshot(State(stage: .arrived)))
        #expect(updates.count == 1)
    }

    @Test func MuteTapIsSentAtOnce() {
        let updater = MakeUpdater()
        updater.Apply(Snapshot(State()))
        clock.now += 0.5
        updater.Apply(Snapshot(State(isMuted: true)))
        #expect(updates == [.update(State(isMuted: true))])
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
        updater.Apply(Snapshot(State(turnText: "100 m")))
        updater.Apply(nil)
        #expect(activity.calls == [.endLeftovers, .start(title: "To Puncak", stage: .driving)])
    }
}
