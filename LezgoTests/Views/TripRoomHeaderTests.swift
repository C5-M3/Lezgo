//
//  TripRoomHeaderTests.swift
//  LezgoTests
//

import CoreGraphics
import Testing
@testable import Lezgo

struct TripRoomHeaderTests {
    @Test func MapKeepsItsSizeAtRestAndWhenScrolledUp() {
        #expect(TripRoomHeader.PullZoom(pull: 0, mapHeight: 320) == 1)
        #expect(TripRoomHeader.PullZoom(pull: -80, mapHeight: 320) == 1)
    }

    @Test func MapGrowsBySamePullDistanceWhenPulledDown() {
        #expect(TripRoomHeader.PullZoom(pull: 160, mapHeight: 320) == 1.5)
    }
}
