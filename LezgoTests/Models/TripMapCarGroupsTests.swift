//
//  TripMapCarGroupsTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Cars so close on the map that their robots would overlap are drawn together, side by side.
struct TripMapCarGroupsTests {
    private static let start = Coordinate(latitude: -7.27, longitude: 112.73)

    /// A car `metres` north of the same point.
    private func Pin(_ name: String, metres: Double, isAlerting: Bool = false, isMe: Bool = false) -> TripMapCarPin {
        TripMapCarPin(
            id: UUID(),
            displayName: name,
            coordinate: Coordinate(
                latitude: Self.start.latitude + metres / 110_600,
                longitude: Self.start.longitude
            ),
            motionState: .driving,
            isLeader: false,
            isMe: isMe,
            isOffline: false,
            isAlerting: isAlerting
        )
    }

    private func Names(_ groups: [TripMapCarGroup]) -> [[String]] {
        groups.map { $0.pins.map(\.displayName) }
    }

    @Test func CarsFarApartStayAlone() {
        let groups = TripMapCarGroup.Make(
            pins: [Pin("Agus", metres: 0), Pin("Budi", metres: 500)],
            within: 100
        )

        #expect(Names(groups) == [["Agus"], ["Budi"]])
    }

    @Test func CarsCloseTogetherAreOneGroup() {
        let groups = TripMapCarGroup.Make(
            pins: [Pin("Agus", metres: 0), Pin("Budi", metres: 50)],
            within: 100
        )

        #expect(Names(groups) == [["Agus", "Budi"]])
    }

    @Test func AChainOfCloseCarsIsOneGroup() {
        let groups = TripMapCarGroup.Make(
            pins: [Pin("Agus", metres: 0), Pin("Budi", metres: 90), Pin("Citra", metres: 180)],
            within: 100
        )

        #expect(Names(groups) == [["Agus", "Budi", "Citra"]])
    }

    @Test func MyCarStaysAloneSoICanAlwaysFindIt() {
        let groups = TripMapCarGroup.Make(
            pins: [Pin("Agus", metres: 0), Pin("Budi", metres: 30, isMe: true), Pin("Citra", metres: 60)],
            within: 100
        )

        #expect(Names(groups) == [["Agus", "Citra"], ["Budi"]])
    }

    @Test func ACarWithAnAlertStaysAloneSoItsWarningShows() {
        let groups = TripMapCarGroup.Make(
            pins: [Pin("Agus", metres: 0), Pin("Budi", metres: 50, isAlerting: true)],
            within: 100
        )

        #expect(Names(groups) == [["Agus"], ["Budi"]])
    }

    @Test func TheTappedCarStaysOnItsCardSoTheCardDoesNotJump() {
        let groups = TripMapCarGroup.Make(pins: [Pin("Agus", metres: 0), Pin("Budi", metres: 50)], within: 100)

        #expect(Names(groups) == [["Agus", "Budi"]])
    }

    @Test func AGroupSitsBetweenItsCars() throws {
        let groups = TripMapCarGroup.Make(
            pins: [Pin("Agus", metres: 0), Pin("Budi", metres: 50)],
            within: 100
        )

        let group = try #require(groups.first)
        #expect((group.coordinate.latitude - (Self.start.latitude + 25.0 / 110_600)).magnitude < 0.000_001)
    }

    @Test func AGroupKeepsItsIdentityWhileTheCarsMove() throws {
        let agus = Pin("Agus", metres: 0)
        let budi = Pin("Budi", metres: 50)
        var movedBudi = budi
        movedBudi.coordinate.latitude += 0.000_1

        let before = try #require(TripMapCarGroup.Make(pins: [agus, budi], within: 100).first)
        let after = try #require(TripMapCarGroup.Make(pins: [agus, movedBudi], within: 100).first)

        #expect(before.id == after.id)
    }

    @Test func NoCarsNoGroups() {
        #expect(TripMapCarGroup.Make(pins: [], within: 100).isEmpty)
    }
}
