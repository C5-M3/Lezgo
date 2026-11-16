//
//  TripMapCarStatusTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The status line of the car status card (`specs/UserStories.md` → US-06, "Car status").
struct TripMapCarStatusTests {
    @Test(arguments: [
        (TripMapCarStatus.Activity.driving(street: "Ahmad Yani Street"), "Driving at Ahmad Yani Street"),
        (.stopped(street: "Ahmad Yani Street"), "Stopped at Ahmad Yani Street"),
        (.driving(street: nil), "Driving"),
        (.stopped(street: nil), "Stopped"),
        (.offline(lastSeen: .seconds(180)), "Last seen 3 min ago")
    ])
    func StatusLineSaysWhatTheCarIsDoingAndWhere(activity: TripMapCarStatus.Activity, expected: String) {
        let status = TripMapCarStatus(id: UUID(), displayName: "Budi", activity: activity, timeLeft: nil)

        #expect(status.statusLine == expected)
    }

    /// The hi-fi's card: "Status: Driving" under the car, with no street.
    @Test(arguments: [
        (TripMapCarStatus.Activity.driving(street: "Ahmad Yani Street"), "Status: Driving"),
        (.driving(street: nil), "Status: Driving"),
        (.stopped(street: "Ahmad Yani Street"), "Status: Stopped"),
        (.offline(lastSeen: .seconds(180)), "Status: Offline")
    ])
    func CardStatusLineNamesTheStatusWithoutTheStreet(activity: TripMapCarStatus.Activity, expected: String) {
        let status = TripMapCarStatus(id: UUID(), displayName: "Budi", activity: activity, timeLeft: nil)

        #expect(status.cardStatusLine == expected)
    }

    @Test func OnlyAnOfflineCarSaysWhenItWasLastSeen() {
        let offline = TripMapCarStatus(id: UUID(), displayName: "Budi", activity: .offline(lastSeen: .seconds(180)))
        let driving = TripMapCarStatus(id: UUID(), displayName: "Budi", activity: .driving(street: "Ahmad Yani Street"))

        #expect(offline.lastSeenLine == "Last seen 3 min ago")
        #expect(driving.lastSeenLine == nil)
    }

    @Test func NextStopLineNamesWhereTheCarIsHeadingBesideTheTimeLeft() {
        let status = TripMapCarStatus(
            id: UUID(),
            displayName: "Budi",
            activity: .driving(street: nil),
            timeLeft: .seconds(3_600),
            nextStopName: "Tunjungan Plaza"
        )

        #expect(status.nextStopLine == "To Tunjungan Plaza")
    }

    @Test func NextStopLineIsEmptyWithoutATimeLeftOrAName() {
        let withoutTime = TripMapCarStatus(
            id: UUID(), displayName: "Budi", activity: .driving(street: nil), nextStopName: "Tunjungan Plaza"
        )
        let withoutName = TripMapCarStatus(
            id: UUID(), displayName: "Budi", activity: .driving(street: nil), timeLeft: .seconds(60)
        )

        #expect(withoutTime.nextStopLine == nil)
        #expect(withoutName.nextStopLine == nil)
    }

    @Test func VeryLongStreetNameIsKeptWhole() {
        let street = "Jalan Raya Prapen Indah Blok A No. 12, Panjang Jiwo, Tenggilis Mejoyo, Surabaya"
        let status = TripMapCarStatus(
            id: UUID(),
            displayName: "Budi",
            activity: .driving(street: street),
            timeLeft: nil
        )

        #expect(status.statusLine == "Driving at \(street)")
    }
}
