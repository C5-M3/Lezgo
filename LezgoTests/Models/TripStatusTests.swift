//
//  TripStatusTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Testing
@testable import Lezgo

struct TripStatusTests {
    @Test func RawValuesMatchTheStoredStrings() {
        #expect(TripStatus.allCases.map(\.rawValue) == ["LOBBY", "IN_TRIP", "ENDED", "CANCELLED"])
    }
}
