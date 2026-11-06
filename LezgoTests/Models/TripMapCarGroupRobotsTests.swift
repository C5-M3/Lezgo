//
//  TripMapCarGroupRobotsTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 06/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Which robots a group of cars shows: the leader first, so its crown is always in sight, and the rest counted once
/// the card is full, until it is opened.
struct TripMapCarGroupRobotsTests {
    private func Pin(_ name: String, isLeader: Bool = false) -> TripMapCarPin {
        TripMapCarPin(
            id: UUID(),
            displayName: name,
            coordinate: Coordinate(latitude: -7.27, longitude: 112.73),
            motionState: .stopped,
            isLeader: isLeader,
            isMe: false,
            isOffline: false
        )
    }

    private func Cars(_ count: Int, leaderAt leaderIndex: Int? = nil) -> TripMapCarGroup {
        TripMapCarGroup(pins: (0..<count).map { Pin("Car \($0)", isLeader: $0 == leaderIndex) })
    }

    @Test func TwoCarsShowBothInTheirOrder() {
        let group = TripMapCarGroup(pins: [Pin("Agus"), Pin("Budi")])

        #expect(group.ShownPins(isOpen: false).map(\.displayName) == ["Agus", "Budi"])
        #expect(group.HiddenCount(isOpen: false) == 0)
    }

    @Test func TheLeaderComesFirst() {
        let group = TripMapCarGroup(pins: [Pin("Budi"), Pin("Citra"), Pin("Agus", isLeader: true)])

        #expect(group.ShownPins(isOpen: false).map(\.displayName) == ["Agus", "Budi", "Citra"])
    }

    @Test func AFullCardCountsTheRest() {
        let group = Cars(10)

        #expect(group.ShownPins(isOpen: false).count == TripMapCarGroup.maxRobots)
        #expect(group.HiddenCount(isOpen: false) == 10 - TripMapCarGroup.maxRobots)
    }

    @Test func TheLeaderIsShownEvenWhenItJoinedLast() {
        let group = Cars(10, leaderAt: 9)

        #expect(group.ShownPins(isOpen: false).first?.displayName == "Car 9")
    }

    @Test func AnOpenCardShowsEveryCar() {
        let group = Cars(10, leaderAt: 9)

        #expect(group.ShownPins(isOpen: true).count == 10)
        #expect(group.HiddenCount(isOpen: true) == 0)
    }

    @Test func TheTappedCarIsShownOnAClosedCardRightAfterTheLeader() {
        let group = Cars(10, leaderAt: 0)
        let tapped = group.pins[8]

        let names = group.ShownPins(isOpen: false, selectedID: tapped.id).map(\.displayName)

        #expect(names == ["Car 0", "Car 8", "Car 1", "Car 2"])
    }

    @Test func OnlyAGroupWithHiddenCarsCanOpen() {
        #expect(Cars(TripMapCarGroup.maxRobots).canOpen == false)
        #expect(Cars(TripMapCarGroup.maxRobots + 1).canOpen)
    }
}
