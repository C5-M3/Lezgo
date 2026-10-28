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
